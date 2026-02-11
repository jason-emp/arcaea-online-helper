import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../models/app_settings.dart';
import '../models/b30r10_data.dart';
import '../services/data_update_service.dart';
import '../services/image_generation_manager.dart';
import '../services/partner_storage_service.dart';
import '../services/score_storage_service.dart';
import '../services/update_service.dart';
import '../services/webview_script_manager.dart';

/// Arcaea WebView 页面
/// 用于登录和访问 Arcaea 官网
class ArcaeaWebViewPage extends StatefulWidget {
  final ImageGenerationManager imageManager;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  
  const ArcaeaWebViewPage({
    super.key,
    required this.imageManager,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<ArcaeaWebViewPage> createState() => ArcaeaWebViewPageState();
}

class ArcaeaWebViewPageState extends State<ArcaeaWebViewPage> {
  // WebView控制器
  InAppWebViewController? webViewController;

  // UI状态
  double progress = 0;
  String currentUrl = '';

  // 服务和管理器
  late final WebViewScriptManager _scriptManager;
  ImageGenerationManager get _imageManager => widget.imageManager;
  late final UpdateService _updateService;
  late final DataUpdateService _dataUpdateService;

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

  // 防止重复显示数据准备提示
  DateTime? _lastDataReadyNotificationTime;
  String? _lastDataReadyUsername;
  static const Duration _dataReadyNotificationCooldown = Duration(seconds: 3);

  // Getters for external access
  bool get isCheckingUpdate => _isCheckingUpdate;
  bool get isUpdatingData => _isUpdatingData;
  String? get currentVersion => _currentVersion;
  String? get latestAvailableVersion => _latestAvailableVersion;
  String? get updateStatusMessage => _updateStatusMessage;
  String? get dataUpdateMessage => _dataUpdateMessage;
  DateTime? get lastDataUpdateTime => _lastDataUpdateTime;
  WebViewScriptManager get scriptManager => _scriptManager;

  @override
  void initState() {
    super.initState();
    _updateService = UpdateService();
    _dataUpdateService = DataUpdateService();
    _scriptManager = WebViewScriptManager(
      onB30R10DataReceived: _handleB30R10Data,
    );
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    await _initializeVersionAndUpdateCheck();
    await _loadLastDataUpdateTime();
  }

  @override
  void dispose() {
    _scriptManager.dispose();
    super.dispose();
  }

  // ==================== 初始化方法 ====================

  Future<void> _initializeVersionAndUpdateCheck() async {
    _currentVersion = await _updateService.getCurrentVersion();
    if (mounted && !_hasAutoCheckedUpdate) {
      _hasAutoCheckedUpdate = true;
      await checkForUpdate(autoTriggered: true);
    }
  }

  // ==================== 更新检查方法 ====================

  Future<void> checkForUpdate({bool autoTriggered = false}) async {
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
              onPressed: launchLatestRelease,
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
                launchLatestRelease();
              },
              child: const Text('前往下载'),
            ),
          ],
        );
      },
    );
  }

  Future<void> launchLatestRelease() async {
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

  Future<void> updateData() async {
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

  Future<void> clearAllData() async {
    try {
      final storageService = ScoreStorageService();
      await storageService.clearAllData();
      
      // 清除搭档数据
      final partnerStorageService = PartnerStorageService();
      await partnerStorageService.clearPartners();
      
      _imageManager.cachedData = null;
      
      if (webViewController != null) {
        final cookieManager = CookieManager.instance();
        await cookieManager.deleteAllCookies();
        await webViewController!.clearCache();
      }
      
      _scriptManager.resetInjectionState();
      
      if (!mounted) return;
      
      _showSnackBar(
        '所有数据已清除（包括登录信息）',
        duration: const Duration(seconds: 3),
      );
      
      if (webViewController != null) {
        _showSnackBar(
          '需要重新登录以使用功能',
          action: SnackBarAction(
            label: '前往登录',
            onPressed: () => webViewController?.reload(),
          ),
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('清除数据失败: $e');
      }
    }
  }

  // ==================== 数据处理方法 ====================

  void _handleB30R10Data(B30R10Data data) {
    _imageManager.cachedData = data;

    if (mounted) {
      // 防止短时间内重复显示相同的提示
      final now = DateTime.now();
      final shouldShow = _lastDataReadyNotificationTime == null ||
          now.difference(_lastDataReadyNotificationTime!) > _dataReadyNotificationCooldown ||
          _lastDataReadyUsername != data.player.username;
      
      if (shouldShow) {
        _lastDataReadyNotificationTime = now;
        _lastDataReadyUsername = data.player.username;
        _showSnackBar('数据已准备: ${data.player.username}');
      }
    }
  }

  Future<void> fetchB30R10Data() async {
    if (webViewController == null) return;

    try {
      // 先检查 DOM 是否就绪，如果没有就等待（Vue.js 异步渲染）
      var domReady = await _scriptManager.checkDOMReady(webViewController!);
      if (!domReady) {
        // 轮询等待卡片渲染，最多等待 10 秒
        for (var i = 1; i <= 10; i++) {
          await Future.delayed(const Duration(milliseconds: 1000));
          domReady = await _scriptManager.checkDOMReady(webViewController!);
          if (domReady) break;
        }
      }
      
      await _scriptManager.exportB30R10Data(webViewController!);
    } catch (e) {
      if (mounted) {
        _showSnackBar('获取数据失败: $e');
      }
    }
  }

  // ==================== 图片生成方法 ====================

  Future<void> generateImage() async {
    if (_imageManager.cachedData == null) {
      await fetchB30R10Data();
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
      if (kDebugMode) {
        debugPrint('[Arcaea Helper] 生成图片失败: $e\n堆栈: $stackTrace');
      }

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
  }

  void _onLoadStart(InAppWebViewController controller, WebUri? url) {
    final rawUrl = url?.toString();
    final wasTargetPage = _scriptManager.state.isTargetPage;
    final isTarget = _scriptManager.isTargetUrl(rawUrl);

    if (isTarget) {
      _scriptManager.cancelTargetPageGraceTimer();
      _scriptManager.state.isTargetPage = true;
    } else if (wasTargetPage && !isTarget) {
      _scriptManager.state.isTargetPage = false;
      _scriptManager.startTargetPageGraceTimer(() {
        if (mounted) {
          _scriptManager.resetInjectionState();
        }
      });
    } else if (!wasTargetPage && isTarget) {
      _scriptManager.cancelTargetPageGraceTimer();
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
    final isLoginRedirect = _scriptManager.isLoginPageWithRedirect(urlString);

    if (isTarget) {
      _scriptManager.cancelTargetPageGraceTimer();
      _scriptManager.state.isTargetPage = true;
      setState(() {
        currentUrl = urlString;
      });

      if (isReload == true) {
        await _tryExtractData(controller);
      }
    } else if (isLoginRedirect) {
      // 登录页面重定向：保持 isTargetPage 状态，等待重定向完成
      _scriptManager.cancelTargetPageGraceTimer();
    } else if (!isTarget && _scriptManager.state.isTargetPage) {
      // 只有在不是登录页面重定向的情况下，才启动宽限期定时器
      _scriptManager.startTargetPageGraceTimer(() {
        _scriptManager.state.isTargetPage = false;
      });
    }
  }

  Future<void> _onLoadStop(InAppWebViewController controller, WebUri? url) async {
    final urlString = url?.toString() ?? '';
    final isLoginRedirect = _scriptManager.isLoginPageWithRedirect(urlString);

    setState(() {
      progress = 1.0;
    });

    final isTarget = _scriptManager.isTargetUrl(urlString);
    
    // 如果是登录页面重定向，保持当前的 isTargetPage 状态，不立即清除
    // 等待重定向完成后再判断
    if (!isLoginRedirect) {
      _scriptManager.state.isTargetPage = isTarget;
    }

    if (isTarget) {
      await _tryExtractData(controller);
    } else if (isLoginRedirect) {
      // 登录页面重定向：等待一段时间后检查是否重定向到目标页面
      Future.delayed(const Duration(milliseconds: 1000), () async {
        try {
          final currentUrl = await controller.getUrl();
          final finalIsTarget = _scriptManager.isTargetUrl(currentUrl?.toString());
          if (finalIsTarget) {
            _scriptManager.state.isTargetPage = true;
            await _tryExtractData(controller);
          }
        } catch (_) {}
      });
    }
  }

  /// 等待 DOM 就绪后从页面提取 B30/R10 数据（Flutter 侧处理，无脚本注入）
  /// Vue.js SPA 页面需要额外时间加载和渲染卡片数据，因此使用轮询机制
  Future<void> _tryExtractData(InAppWebViewController controller) async {
    // 初始等待，给页面基本加载的时间
    await Future.delayed(AppConstants.initialDelay);

    // Vue.js SPA 页面可能需要较长时间才能完成数据加载和卡片渲染
    // 使用轮询机制，最多等待 15 秒
    const maxAttempts = 15;
    const pollInterval = Duration(milliseconds: 1000);
    
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final domReady = await _scriptManager.checkDOMReady(controller);
      
      if (domReady) {
        await _scriptManager.extractB30R10Data(controller);
        return;
      }
      
      // 检查是否仍在目标页面
      try {
        final currentUrl = await controller.getUrl();
        final stillOnTarget = _scriptManager.isTargetUrl(currentUrl?.toString());
        if (!stillOnTarget) return;
      } catch (_) {}
      
      if (attempt < maxAttempts) {
        await Future.delayed(pollInterval);
      }
    }
  }

  void _onLoadResource(InAppWebViewController controller, LoadedResource resource) {
    final resourceUrl = resource.url?.toString() ?? '';
    if (_scriptManager.isTargetUrl(resourceUrl)) {
      _scriptManager.state.isTargetPage = true;
    }
  }

  void _onConsoleMessage(InAppWebViewController controller, ConsoleMessage consoleMessage) {
    if (kDebugMode) {
      debugPrint('[WebView Console] ${consoleMessage.messageLevel}: ${consoleMessage.message}');
    }
  }

  void _onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    if (kDebugMode) {
      debugPrint('[WebView Error] URL: ${request.url}, Error: ${error.description}, Type: ${error.type}');
    }
  }

  void _onReceivedHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    if (kDebugMode) {
      debugPrint('[WebView HTTP Error] URL: ${request.url}, Status: ${response.statusCode}');
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
            onPressed: _imageManager.isGenerating ? null : generateImage,
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
        sharedCookiesEnabled: true, // iOS: 与系统/WKWebView共享Cookie
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
