import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/constants.dart';
import 'models/app_settings.dart';
import 'models/b30r10_data.dart';
import 'services/data_update_service.dart';
import 'services/image_generation_manager.dart';
import 'services/update_service.dart';
import 'services/webview_script_manager.dart';
import 'widgets/settings_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 仅在Android平台启用WebView调试
  if (defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  // 捕获全局错误
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter错误: ${details.exception}');
    debugPrint('堆栈: ${details.stack}');
  };

  runApp(const ArcaeaHelperApp());
}

class ArcaeaHelperApp extends StatelessWidget {
  const ArcaeaHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcaea Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667EEA),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const ArcaeaWebViewPage(),
    );
  }
}

class ArcaeaWebViewPage extends StatefulWidget {
  const ArcaeaWebViewPage({super.key});

  @override
  State<ArcaeaWebViewPage> createState() => _ArcaeaWebViewPageState();
}

class _ArcaeaWebViewPageState extends State<ArcaeaWebViewPage> {
  // WebView控制器
  InAppWebViewController? webViewController;

  // UI状态
  double progress = 0;
  String currentUrl = '';

  // 服务和管理器
  late final WebViewScriptManager _scriptManager;
  late final ImageGenerationManager _imageManager;
  late final UpdateService _updateService;
  late final DataUpdateService _dataUpdateService;

  // 设置
  late AppSettings _settings;

  // 更新检查状态
  bool _isCheckingUpdate = false;
  String? _currentVersion;
  String? _latestAvailableVersion;
  String? _updateStatusMessage;
  bool _hasAutoCheckedUpdate = false;

  // 数据更新状态
  bool _isUpdatingData = false;
  String? _dataUpdateMessage;
  DateTime? _lastDataUpdateTime;

  @override
  void initState() {
    super.initState();

    // 初始化服务和管理器
    _updateService = UpdateService();
    _dataUpdateService = DataUpdateService();
    _imageManager = ImageGenerationManager();
    _scriptManager = WebViewScriptManager(
      onB30R10DataReceived: _handleB30R10Data,
      onDebugMessage: (message) => debugPrint('[ScriptManager] $message'),
    );

    // 初始化设置
    _settings = AppSettings();

    // 异步初始化
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    await _loadSettings();
    await _scriptManager.preloadAssets();
    await _initializeVersionAndUpdateCheck();
    await _loadLastDataUpdateTime();
  }

  @override
  void dispose() {
    _scriptManager.dispose();
    super.dispose();
  }

  // ==================== 初始化方法 ====================

  Future<void> _loadSettings() async {
    try {
      final settings = await AppSettings.load();
      if (mounted) {
        setState(() {
          _settings = settings;
        });
      }
    } catch (e) {
      debugPrint('[Arcaea Helper] 加载设置失败: $e');
    }
  }

  Future<void> _initializeVersionAndUpdateCheck() async {
    _currentVersion = await _updateService.getCurrentVersion();
    if (mounted && !_hasAutoCheckedUpdate) {
      _hasAutoCheckedUpdate = true;
      await _checkForUpdate(autoTriggered: true);
    }
  }

  // ==================== 更新检查方法 ====================

  Future<void> _checkForUpdate({bool autoTriggered = false}) async {
    if (_isCheckingUpdate) return;

    setState(() {
      _isCheckingUpdate = true;
      _updateStatusMessage = '正在检查更新...';
    });

    try {
      final result = await _updateService.checkForUpdate();

      if (!mounted) return;

      setState(() {
        _currentVersion = result.currentVersion;
        _latestAvailableVersion = result.latestVersion;
        _updateStatusMessage = result.message;
      });

      if (result.hasUpdate) {
        if (autoTriggered) {
          await _showUpdateDialog(result.latestVersion!);
        } else {
          _showSnackBar(
            '发现新版本 ${result.latestVersion}',
            action: SnackBarAction(
              label: '前往',
              onPressed: _launchLatestRelease,
            ),
          );
        }
      } else if (!autoTriggered) {
        _showSnackBar('当前版本 ${result.currentVersion} 已是最新');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateStatusMessage = '检查更新失败: $e';
        });
        if (!autoTriggered) {
          _showSnackBar('检查更新失败: $e');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  Future<void> _showUpdateDialog(String latestVersion) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('发现新版本'),
          content: Text('检测到最新版本 $latestVersion，可前往 GitHub 下载最新构建。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('稍后再说'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _launchLatestRelease();
              },
              child: const Text('前往下载'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchLatestRelease() async {
    final uri = Uri.parse(AppConstants.githubReleaseUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showSnackBar('无法打开浏览器，请稍后再试');
    }
  }

  // ==================== 数据更新方法 ====================

  Future<void> _loadLastDataUpdateTime() async {
    final lastUpdate = await _dataUpdateService.getLastUpdateTime();
    if (mounted) {
      setState(() {
        _lastDataUpdateTime = lastUpdate;
      });
    }
  }

  Future<void> _updateData() async {
    if (_isUpdatingData) return;

    setState(() {
      _isUpdatingData = true;
      _dataUpdateMessage = '正在下载数据...';
    });

    try {
      final result = await _dataUpdateService.updateAllData();

      if (!mounted) return;

      setState(() {
        _dataUpdateMessage = result.message;
        _lastDataUpdateTime = result.lastUpdateTime;
      });

      if (result.success) {
        _showSnackBar(
          '数据更新成功',
          duration: const Duration(seconds: 2),
        );
        
        if (_scriptManager.state.isTargetPage && webViewController != null) {
          _showSnackBar(
            '建议刷新页面以应用新数据',
            action: SnackBarAction(
              label: '刷新',
              onPressed: () => webViewController?.reload(),
            ),
            duration: const Duration(seconds: 5),
          );
        }
      } else {
        _showSnackBar(result.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dataUpdateMessage = '更新失败: $e';
        });
        _showSnackBar('数据更新失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingData = false;
        });
      }
    }
  }

  // ==================== 设置管理方法 ====================

  Future<void> _saveSettings() async {
    try {
      await _settings.save();
      debugPrint('[Arcaea Helper] 设置已保存');
      await _applySettings();
    } catch (e) {
      debugPrint('[Arcaea Helper] 保存设置失败: $e');
    }
  }

  Future<void> _applySettings() async {
    if (webViewController == null) return;
    await _scriptManager.applySettings(webViewController!, _settings);
  }

  void _onSettingsChanged(AppSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    _saveSettings();
  }

  // ==================== 数据处理方法 ====================

  void _handleB30R10Data(B30R10Data data) {
    _imageManager.cachedData = data;
    debugPrint('[Arcaea Helper] 数据已缓存: ${data.player.username}');

    if (mounted) {
      _showSnackBar('数据已准备: ${data.player.username}');
    }
  }

  Future<void> _fetchB30R10Data() async {
    if (webViewController == null) return;

    try {
      debugPrint('[Arcaea Helper] 开始获取B30/R10数据...');
      await _scriptManager.exportB30R10Data(webViewController!);
    } catch (e, stackTrace) {
      debugPrint('[Arcaea Helper] 获取数据失败: $e\n堆栈: $stackTrace');
      if (mounted) {
        _showSnackBar('获取数据失败: $e');
      }
    }
  }

  // ==================== 图片生成方法 ====================

  Future<void> _generateImage() async {
    if (_imageManager.cachedData == null) {
      await _fetchB30R10Data();
      await Future.delayed(const Duration(milliseconds: 500));

      if (_imageManager.cachedData == null) {
        if (mounted) {
          _showSnackBar('请等待数据加载完成后再试');
        }
        return;
      }
    }

    setState(() {});

    try {
      final fileName = await _imageManager.generateImage(
        context: context,
        onProgressUpdate: (progress) {
          if (mounted) {
            setState(() {});
          }
        },
      );

      if (mounted) {
        _showSnackBar(
          '图片已保存到相册: $fileName',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[Arcaea Helper] 生成图片失败: $e\n堆栈: $stackTrace');

      if (mounted) {
        _showSnackBar('生成图片失败: $e');
      }
    } finally {
      setState(() {});
    }
  }

  // ==================== WebView事件处理方法 ====================

  void _onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;

    // 注入基础处理器
    controller.addJavaScriptHandler(
      handlerName: AppConstants.getSharedAssetHandler,
      callback: (args) async {
        final assetPath = args[0] as String;
        return await rootBundle.loadString(assetPath);
      },
    );

    // 添加导出B30/R10数据的处理器
    controller.addJavaScriptHandler(
      handlerName: AppConstants.exportB30R10DataHandler,
      callback: (args) {
        _scriptManager.handleB30R10DataExport(args);
        return null;
      },
    );
  }

  void _onLoadStart(InAppWebViewController controller, WebUri? url) {
    debugPrint('[WebView] 开始加载: $url');
    final rawUrl = url?.toString();
    final wasTargetPage = _scriptManager.state.isTargetPage;
    final isTarget = _scriptManager.isTargetUrl(rawUrl);

    // 如果是目标页面的加载开始,立即重置注入状态
    if (isTarget) {
      debugPrint('[Arcaea Helper] 检测到目标页面开始加载，重置注入状态');
      _scriptManager.state.hasInjectedScript = false;
      _scriptManager.state.hasTriggeredProcessing = false;
      _scriptManager.state.aggressiveAttempts = 0;
      _scriptManager.stopAggressiveLoop();
      _scriptManager.cancelTargetPageGraceTimer();
      _scriptManager.state.isTargetPage = true;
    }
    // 如果从目标页离开,设置宽限期
    else if (wasTargetPage && !isTarget) {
      debugPrint('[Arcaea Helper] 检测到离开目标页面，设置宽限期');
      _scriptManager.state.isTargetPage = false;
      _scriptManager.startTargetPageGraceTimer(() {
        if (mounted) {
          _scriptManager.resetInjectionState();
        }
      });
    } else if (!wasTargetPage && isTarget) {
      _scriptManager.cancelTargetPageGraceTimer();
      debugPrint('[Arcaea Helper] 回到目标页面，取消宽限期');
      _scriptManager.state.isTargetPage = true;
    }

    setState(() {
      currentUrl = rawUrl ?? '';
      progress = 0;
    });
  }

  void _onProgressChanged(InAppWebViewController controller, int newProgress) {
    setState(() {
      progress = newProgress / 100;
    });
  }

  Future<void> _onUpdateVisitedHistory(
    InAppWebViewController controller,
    WebUri? url,
    bool? isReload,
  ) async {
    final urlString = url?.toString() ?? '';
    final isTarget = _scriptManager.isTargetUrl(urlString);

    debugPrint('[WebView] onUpdateVisitedHistory - url=$urlString, isReload=$isReload, isTarget=$isTarget');

    // 如果是刷新操作且是目标页面,强制重新注入
    if (isReload == true && isTarget) {
      debugPrint('[Arcaea Helper] 检测到页面刷新,强制重置并重新注入');
      _scriptManager.state.hasInjectedScript = false;
      _scriptManager.state.hasTriggeredProcessing = false;
      _scriptManager.state.aggressiveAttempts = 0;
      _scriptManager.stopAggressiveLoop();
      _scriptManager.cancelTargetPageGraceTimer();
      _scriptManager.state.isTargetPage = true;
      _scriptManager.state.lastTargetPageTime = null;

      setState(() {
        currentUrl = urlString;
      });

      await Future.delayed(const Duration(milliseconds: 1000));
      final domReady = await _scriptManager.checkDOMReady(controller);

      if (!domReady) {
        await Future.delayed(AppConstants.domCheckDelay);
      }

      _scriptManager.startAggressiveInjectionLoop(
        controller,
        _settings,
        reason: 'reload',
        forceRestart: true,
      );
      return;
    }

    // 如果URL变成了目标页面(非刷新场景)
    if (isTarget) {
      _scriptManager.cancelTargetPageGraceTimer();

      final now = DateTime.now();
      final isQuickReturn = _scriptManager.state.lastTargetPageTime != null &&
          now.difference(_scriptManager.state.lastTargetPageTime!) < AppConstants.targetPageGracePeriod;

      if (!_scriptManager.state.isTargetPage || isQuickReturn) {
        debugPrint('[Arcaea Helper] URL变为目标页面，准备注入 (快速返回: $isQuickReturn)');
        _scriptManager.state.isTargetPage = true;
        setState(() {
          currentUrl = urlString;
        });

        if (isQuickReturn) {
          debugPrint('[Arcaea Helper] 快速返回场景,重置注入状态');
          _scriptManager.state.hasInjectedScript = false;
          _scriptManager.state.hasTriggeredProcessing = false;
          _scriptManager.state.aggressiveAttempts = 0;
          _scriptManager.stopAggressiveLoop();
        }

        await Future.delayed(const Duration(milliseconds: 1000));
        final domReady = await _scriptManager.checkDOMReady(controller);

        if (!domReady) {
          await Future.delayed(AppConstants.domCheckDelay);
        }

        _scriptManager.startAggressiveInjectionLoop(
          controller,
          _settings,
          reason: 'updateVisitedHistory',
          forceRestart: true,
        );
      }
    } else if (!isTarget && _scriptManager.state.isTargetPage) {
      debugPrint('[Arcaea Helper] 离开目标页面，等待宽限期');
      _scriptManager.startTargetPageGraceTimer(() {
        // 宽限期处理在startTargetPageGraceTimer中
      });
    }
  }

  Future<void> _onLoadStop(InAppWebViewController controller, WebUri? url) async {
    final urlString = url?.toString() ?? '';
    debugPrint('[WebView] 加载完成: $urlString');

    setState(() {
      progress = 1.0;
    });

    final isTarget = _scriptManager.isTargetUrl(urlString);
    debugPrint('[Arcaea Helper] onLoadStop - isTarget=$isTarget');
    _scriptManager.state.isTargetPage = isTarget;

    if (isTarget) {
      debugPrint('[Arcaea Helper] 检测到目标页面，延迟后开始注入');
      await Future.delayed(AppConstants.initialDelay);

      final domReady = await _scriptManager.checkDOMReady(controller);
      debugPrint('[Arcaea Helper] DOM就绪状态: $domReady');

      if (!domReady) {
        await Future.delayed(AppConstants.domCheckDelay);
      }

      _scriptManager.startAggressiveInjectionLoop(
        controller,
        _settings,
        reason: 'loadStop',
        forceRestart: true,
      );
    } else {
      debugPrint('[Arcaea Helper] 非目标页面，停止注入循环');
      _scriptManager.stopAggressiveLoop();
    }
  }

  void _onLoadResource(InAppWebViewController controller, LoadedResource resource) {
    final resourceUrl = resource.url?.toString() ?? '';
    if (_scriptManager.isTargetUrl(resourceUrl)) {
      if (!_scriptManager.state.isTargetPage) {
        debugPrint('[WebView] 资源阶段检测到目标页面: $resourceUrl');
      }
      _scriptManager.state.isTargetPage = true;
      if (_scriptManager.state.aggressiveLoopActive) {
        _scriptManager.state.aggressiveAttempts = 0;
      } else {
        _scriptManager.startAggressiveInjectionLoop(
          controller,
          _settings,
          reason: 'resource',
        );
      }
    }
  }

  void _onConsoleMessage(InAppWebViewController controller, ConsoleMessage consoleMessage) {
    debugPrint('[WebView Console] ${consoleMessage.messageLevel}: ${consoleMessage.message}');
  }

  void _onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    debugPrint('[WebView Error] URL: ${request.url}, Error: ${error.description}, Type: ${error.type}');
    _scriptManager.stopAggressiveLoop();
  }

  void _onReceivedHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    debugPrint('[WebView HTTP Error] URL: ${request.url}, Status: ${response.statusCode}');
    final statusCode = response.statusCode;
    if (statusCode != null && statusCode >= 400) {
      _scriptManager.stopAggressiveLoop();
    }
  }

  // ==================== UI构建方法 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (progress < 1.0) _buildProgressBar(),
          if (_imageManager.isGenerating) _buildGenerationProgress(),
          Expanded(child: _buildWebView()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Arcaea Helper'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        if (_scriptManager.state.isTargetPage)
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: '生成B30/R10图片',
            onPressed: _imageManager.isGenerating ? null : _generateImage,
          ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showSettingsDialog,
        ),
        if (currentUrl.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => webViewController?.reload(),
          ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.grey[200],
      valueColor: AlwaysStoppedAnimation<Color>(
        Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildGenerationProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _imageManager.progress,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showSettingsDialog(
      context: context,
      settings: _settings,
      onSettingsChanged: _onSettingsChanged,
      onGenerateImage: _generateImage,
      onDownloadLatest: _launchLatestRelease,
      onCheckUpdate: _checkForUpdate,
      onUpdateData: _updateData,
      isCheckingUpdate: _isCheckingUpdate,
      isGeneratingImage: _imageManager.isGenerating,
      isUpdatingData: _isUpdatingData,
      canGenerateImage: _scriptManager.state.isTargetPage,
      currentVersion: _currentVersion,
      latestVersion: _latestAvailableVersion,
      updateStatusMessage: _updateStatusMessage,
      dataUpdateMessage: _dataUpdateMessage,
      lastDataUpdateTime: _lastDataUpdateTime,
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(AppConstants.initialUrl),
      ),
      initialSettings: InAppWebViewSettings(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        supportZoom: true,
        useOnLoadResource: true,
      ),
      onWebViewCreated: _onWebViewCreated,
      onLoadStart: _onLoadStart,
      onProgressChanged: _onProgressChanged,
      onUpdateVisitedHistory: _onUpdateVisitedHistory,
      onLoadStop: _onLoadStop,
      onLoadResource: _onLoadResource,
      onConsoleMessage: _onConsoleMessage,
      onReceivedError: _onReceivedError,
      onReceivedHttpError: _onReceivedHttpError,
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        debugPrint('[WebView] 导航请求: ${navigationAction.request.url}');
        return NavigationActionPolicy.ALLOW;
      },
    );
  }

  // ==================== 辅助方法 ====================

  void _showSnackBar(String message, {SnackBarAction? action, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }
}
