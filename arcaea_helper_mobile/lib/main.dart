import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

import 'models/b30r10_data.dart';
import 'services/image_generator_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 仅在Android平台启用WebView调试（iOS不支持此方法）
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
  InAppWebViewController? webViewController;
  double progress = 0;
  String currentUrl = '';
  bool showSettings = false;
  bool _hasInjectedScript = false;
  bool _hasTriggeredProcessing = false;

  // 设置状态
  bool showCharts = false;
  bool showConstant = true;
  bool showPTT = true;
  bool showTargetScore = true;
  bool showDownloadButtons = true;
  bool _isTargetPage = false;

  Timer? _aggressiveTimer;
  bool _aggressiveLoopActive = false;
  bool _isPerformingAggressiveCycle = false;
  int _aggressiveAttempts = 0;
  static const int _maxAggressiveAttempts = 50;
  static const Duration _aggressiveInterval = Duration(milliseconds: 400);

  String? _cachedCalculatorScript;
  String? _cachedDataLoaderScript;
  String? _cachedContentScript;
  String? _cachedStyles;
  String? _cachedChartConstant;
  String? _cachedSonglist;

  // 图片生成状态
  bool _isGeneratingImage = false;
  String _generationProgress = '';
  B30R10Data? _cachedB30R10Data;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _preloadInjectionAssets();
  }

  @override
  void dispose() {
    _stopAggressiveLoop();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        showCharts = prefs.getBool('showCharts') ?? false;
        showConstant = prefs.getBool('showConstant') ?? true;
        showPTT = prefs.getBool('showPTT') ?? true;
        showTargetScore = prefs.getBool('showTargetScore') ?? true;
        showDownloadButtons = prefs.getBool('showDownloadButtons') ?? true;
      });
      debugPrint('[Arcaea Helper] 设置已加载: showCharts=$showCharts, showConstant=$showConstant, showPTT=$showPTT, showTargetScore=$showTargetScore, showDownloadButtons=$showDownloadButtons');
    } catch (e) {
      debugPrint('[Arcaea Helper] 加载设置失败: $e');
    }
  }

  void _preloadInjectionAssets() {
    unawaited(_ensureAssetsCached());
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('showCharts', showCharts);
      await prefs.setBool('showConstant', showConstant);
      await prefs.setBool('showPTT', showPTT);
      await prefs.setBool('showTargetScore', showTargetScore);
      await prefs.setBool('showDownloadButtons', showDownloadButtons);
      debugPrint('[Arcaea Helper] 设置已保存: showCharts=$showCharts, showConstant=$showConstant, showPTT=$showPTT, showTargetScore=$showTargetScore, showDownloadButtons=$showDownloadButtons');
      _applySettings();
    } catch (e) {
      debugPrint('[Arcaea Helper] 保存设置失败: $e');
    }
  }

  Future<void> _applySettings() async {
    if (webViewController == null) return;

    await webViewController!.evaluateJavascript(source: '''
      (function() {
        if (typeof window.applySettings === 'function') {
          window.applySettings({
            showCharts: $showCharts,
            showConstant: $showConstant,
            showPTT: $showPTT,
            showTargetScore: $showTargetScore,
            showDownloadButtons: $showDownloadButtons,
          });
          console.log('[Arcaea Helper Flutter] 设置已更新');
        } else {
          console.warn('[Arcaea Helper Flutter] applySettings 函数未找到');
        }
      })();
    ''');
  }

  Future<String> _loadAssetAsString(String path) async {
    return await rootBundle.loadString(path);
  }

  Future<void> _ensureAssetsCached() async {
    _cachedCalculatorScript ??=
        await _loadAssetAsString('web/js/arcaea-calculator.js');
    _cachedDataLoaderScript ??=
        await _loadAssetAsString('web/js/arcaea-data-loader.js');
    _cachedContentScript ??=
        await _loadAssetAsString('web/js/flutter-content.js');
    _cachedStyles ??= await _loadAssetAsString('web/css/arcaea-styles.css');
    _cachedChartConstant ??=
        await _loadAssetAsString('assets/data/ChartConstant.json');
    _cachedSonglist ??=
        await _loadAssetAsString('assets/data/Songlist.json');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arcaea Helper'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 生成图片按钮
          if (_isTargetPage && _cachedB30R10Data != null && !_isGeneratingImage)
            IconButton(
              icon: const Icon(Icons.image),
              tooltip: '生成B30/R10图片',
              onPressed: _generateImage,
            ),
          IconButton(
            icon: Icon(showSettings ? Icons.close : Icons.settings),
            onPressed: () {
              setState(() {
                showSettings = !showSettings;
              });
            },
          ),
          if (currentUrl.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                webViewController?.reload();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (progress < 1.0)
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          if (_isGeneratingImage)
            Container(
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
                      _generationProgress,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (showSettings)
            _buildSettingsPanel(),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://arcaea.lowiro.com/zh/profile/potential'),
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
              onWebViewCreated: (controller) async {
                webViewController = controller;

                // 注入基础脚本
                controller.addJavaScriptHandler(
                  handlerName: 'getSharedAsset',
                  callback: (args) async {
                    final assetPath = args[0] as String;
                    return await _loadAssetAsString(assetPath);
                  },
                );

                // 添加导出B30/R10数据的处理器
                controller.addJavaScriptHandler(
                  handlerName: 'exportB30R10Data',
                  callback: (args) async {
                    debugPrint('[Arcaea Helper] 接收到B30/R10数据');
                    try {
                      final jsonData = args[0] as Map<String, dynamic>;
                      _cachedB30R10Data = B30R10Data.fromJson(jsonData);
                      debugPrint('[Arcaea Helper] 数据已缓存: ${_cachedB30R10Data!.player.username}');
                      
                      // 显示提示
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('数据已准备: ${_cachedB30R10Data!.player.username}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                      
                      return {'success': true};
                    } catch (e) {
                      debugPrint('[Arcaea Helper] 解析数据失败: $e');
                      return {'success': false, 'error': e.toString()};
                    }
                  },
                );
              },
              onLoadStart: (controller, url) {
                debugPrint('[WebView] 开始加载: $url');
                _resetInjectionState();
                final rawUrl = url?.toString();
                _isTargetPage = _isTargetUrl(rawUrl);
                setState(() {
                  currentUrl = rawUrl ?? '';
                  progress = 0;
                });
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  this.progress = progress / 100;
                });
              },
              onLoadStop: (controller, url) async {
                debugPrint('[WebView] 加载完成: $url');
                setState(() {
                  progress = 1.0;
                });

                final isTarget = _isTargetUrl(url?.toString());
                _isTargetPage = isTarget;
                if (isTarget) {
                  _startAggressiveInjectionLoop(controller, reason: 'loadStop', forceRestart: true);
                } else {
                  _stopAggressiveLoop();
                }
              },
              onLoadResource: (controller, resource) {
                final resourceUrl = resource.url?.toString() ?? '';
                if (_isTargetUrl(resourceUrl)) {
                  if (!_isTargetPage) {
                    debugPrint('[WebView] 资源阶段检测到目标页面: $resourceUrl');
                  }
                  _isTargetPage = true;
                  if (_aggressiveLoopActive) {
                    _aggressiveAttempts = 0;
                  } else {
                    _startAggressiveInjectionLoop(controller, reason: 'resource');
                  }
                }
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint(
                    '[WebView Console] ${consoleMessage.messageLevel}: ${consoleMessage.message}');
              },
              onReceivedError: (controller, request, error) {
                debugPrint('[WebView Error] URL: ${request.url}, Error: ${error.description}, Type: ${error.type}');
                _stopAggressiveLoop();
              },
              onReceivedHttpError: (controller, request, response) {
                debugPrint('[WebView HTTP Error] URL: ${request.url}, Status: ${response.statusCode}');
                final statusCode = response.statusCode;
                if (statusCode != null && statusCode >= 400) {
                  _stopAggressiveLoop();
                }
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                debugPrint('[WebView] 导航请求: ${navigationAction.request.url}');
                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '显示设置',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingSwitch(
            '显示图表',
            'Best 30 / Recent 10 的 PTT 变化图表',
            showCharts,
            (value) {
              setState(() {
                showCharts = value;
              });
              _saveSettings();
            },
          ),
          _buildSettingSwitch(
            '显示定数',
            '在曲目名称旁显示谱面定数',
            showConstant,
            (value) {
              setState(() {
                showConstant = value;
              });
              _saveSettings();
            },
          ),
          _buildSettingSwitch(
            '显示单曲PTT',
            '在曲目旁显示该曲目的PTT值',
            showPTT,
            (value) {
              setState(() {
                showPTT = value;
              });
              _saveSettings();
            },
          ),
          _buildSettingSwitch(
            '显示目标分数',
            '显示使显示PTT +0.01 所需的目标分数',
            showTargetScore,
            (value) {
              setState(() {
                showTargetScore = value;
              });
              _saveSettings();
            },
          ),
          _buildSettingSwitch(
            '显示下载按钮',
            '显示截图下载和背景选择按钮',
            showDownloadButtons,
            (value) {
              setState(() {
                showDownloadButtons = value;
              });
              _saveSettings();
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isTargetPage && !_isGeneratingImage ? _generateImage : null,
                  icon: const Icon(Icons.image),
                  label: const Text('生成B30/R10图片'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '自动获取页面数据并生成精美图片',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _launchLatestRelease,
            icon: const Icon(Icons.download),
            label: const Text('下载最新版本'),
          ),
          const SizedBox(height: 8),
          Text(
            '跳转至GitHub发布页下载最新版本',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _launchLatestRelease() async {
    const releaseUrl = 'https://github.com/jason-emp/arcaea-online-helper/releases/latest';
    final uri = Uri.parse(releaseUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开浏览器，请稍后再试')),
      );
    }
  }

  /// 从WebView获取B30/R10数据
  Future<void> _fetchB30R10Data() async {
    if (webViewController == null) return;

    try {
      debugPrint('[Arcaea Helper] 开始获取B30/R10数据...');
      
      await webViewController!.evaluateJavascript(source: '''
        (async function() {
          if (typeof window.exportB30R10Data === 'function') {
            const data = await window.exportB30R10Data();
            if (data) {
              window.flutter_inappwebview.callHandler('exportB30R10Data', data);
              console.log('[Arcaea Helper] 数据已发送到Flutter');
            } else {
              console.error('[Arcaea Helper] 数据导出失败');
            }
          } else {
            console.error('[Arcaea Helper] exportB30R10Data 函数不存在');
          }
        })();
      ''');
    } catch (e) {
      debugPrint('[Arcaea Helper] 获取数据失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取数据失败: $e')),
        );
      }
    }
  }

  /// 生成B30/R10图片
  Future<void> _generateImage() async {
    if (_cachedB30R10Data == null) {
      // 如果没有缓存数据，先获取
      await _fetchB30R10Data();
      
      // 等待一小段时间让数据处理完成
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_cachedB30R10Data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请等待数据加载完成后再试')),
          );
        }
        return;
      }
    }

    setState(() {
      _isGeneratingImage = true;
      _generationProgress = '准备生成图片...';
    });

    try {
      // 请求存储权限
      if (Platform.isAndroid || Platform.isIOS) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          final granted = await Gal.requestAccess();
          if (!granted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('需要相册访问权限才能保存图片')),
              );
            }
            setState(() {
              _isGeneratingImage = false;
              _generationProgress = '';
            });
            return;
          }
        }
        debugPrint('[Arcaea Helper] 已获得相册访问权限');
      }

      // 生成图片
      final imageBytes = await ImageGeneratorService.generateImage(
        _cachedB30R10Data!,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _generationProgress = progress;
            });
          }
        },
      );

      // 保存图片到临时目录
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'arcaea-b30r10-${_cachedB30R10Data!.player.username}-$timestamp.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      debugPrint('[Arcaea Helper] 图片已生成: ${file.path}');

      // 保存到相册
      await Gal.putImage(file.path, album: 'Arcaea Helper');
      debugPrint('[Arcaea Helper] 图片已保存到相册');

      setState(() {
        _isGeneratingImage = false;
        _generationProgress = '';
      });

      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图片已保存到相册: $fileName'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[Arcaea Helper] 生成图片失败: $e');
      debugPrint('[Arcaea Helper] 堆栈: $stackTrace');
      
      setState(() {
        _isGeneratingImage = false;
        _generationProgress = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成图片失败: $e')),
        );
      }
    }
  }

  void _resetInjectionState() {
    _hasInjectedScript = false;
    _hasTriggeredProcessing = false;
    _isTargetPage = false;
    _aggressiveAttempts = 0;
    _isPerformingAggressiveCycle = false;
    _stopAggressiveLoop();
  }

  bool _isTargetUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse(rawUrl);
      return uri.host.contains('arcaea.lowiro.com') &&
          uri.path.contains('/profile/potential');
    } catch (_) {
      return rawUrl.contains('arcaea.lowiro.com') &&
          rawUrl.contains('/profile/potential');
    }
  }

  void _startAggressiveInjectionLoop(
    InAppWebViewController controller, {
    String reason = 'manual',
    bool forceRestart = false,
  }) {
    if (!_isTargetPage) {
      return;
    }

    if (_aggressiveLoopActive && !forceRestart) {
      return;
    }

    if (forceRestart) {
      _stopAggressiveLoop();
    }

    if (_aggressiveLoopActive) {
      return;
    }

    debugPrint('[Arcaea Helper] 启动激进注入循环 ($reason)');
    _aggressiveAttempts = 0;
    _aggressiveLoopActive = true;
    unawaited(
        _performAggressiveInjectionStep(controller, reason: 'initial-$reason'));
    _aggressiveTimer?.cancel();
    _aggressiveTimer = Timer.periodic(_aggressiveInterval, (_) {
      unawaited(
          _performAggressiveInjectionStep(controller, reason: 'timer-$reason'));
    });

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _startContinuousCheck(controller);
    }
  }

  Future<void> _performAggressiveInjectionStep(
    InAppWebViewController controller, {
    String reason = '',
  }) async {
    if (!mounted) {
      _stopAggressiveLoop();
      return;
    }

    if (_isPerformingAggressiveCycle) {
      return;
    }

    if (!_isTargetPage) {
      _stopAggressiveLoop();
      return;
    }

    if (_hasInjectedScript && _hasTriggeredProcessing) {
      _stopAggressiveLoop();
      return;
    }

    _isPerformingAggressiveCycle = true;
    _aggressiveAttempts++;

    try {
      if (!_hasInjectedScript) {
        await _injectArcaeaHelper(controller);
      } else {
        await _ensureScriptTriggered(controller);
      }
    } catch (e, stackTrace) {
      debugPrint('[Arcaea Helper] 激进注入循环错误($reason): $e');
      debugPrint('[Arcaea Helper] 堆栈: $stackTrace');
    } finally {
      _isPerformingAggressiveCycle = false;
    }

    if (_hasInjectedScript && _hasTriggeredProcessing) {
      debugPrint('[Arcaea Helper] 激进注入循环完成');
      _stopAggressiveLoop();
      return;
    }

    if (_aggressiveAttempts >= _maxAggressiveAttempts) {
      debugPrint('[Arcaea Helper] 激进注入循环达到上限 ($reason)');
      _stopAggressiveLoop();
    }
  }

  void _stopAggressiveLoop() {
    _aggressiveTimer?.cancel();
    _aggressiveTimer = null;
    _aggressiveLoopActive = false;
    _isPerformingAggressiveCycle = false;
  }

  Future<void> _injectArcaeaHelper(InAppWebViewController controller) async {
    try {
      debugPrint('[Arcaea Helper] 开始注入脚本...');

      // 加载核心模块
      await _ensureAssetsCached();
      final calculator = _cachedCalculatorScript!;
      final dataLoader = _cachedDataLoaderScript!;
      final contentScript = _cachedContentScript!;
      final styles = _cachedStyles!;
      final chartConstant = _cachedChartConstant!;
      final songlist = _cachedSonglist!;

      debugPrint('[Arcaea Helper] 资源加载完成');

      // 1. 注入样式
      await controller.evaluateJavascript(source: '''
        (function() {
          if (!document.getElementById('arcaea-helper-styles')) {
            const style = document.createElement('style');
            style.id = 'arcaea-helper-styles';
            style.textContent = `$styles`;
            document.head.appendChild(style);
            console.log('[Arcaea Helper] 样式已注入');
          }
        })();
      ''');

      // 2. 注入核心计算模块
      await controller.evaluateJavascript(source: calculator);
      debugPrint('[Arcaea Helper] 计算模块已注入');

      // 3. 注入数据加载模块
      await controller.evaluateJavascript(source: dataLoader);
      debugPrint('[Arcaea Helper] 数据加载模块已注入');

      // 4. 初始化数据
      await controller.evaluateJavascript(source: '''
        (function() {
          try {
            const chartConstantData = $chartConstant;
            const songlistData = $songlist;
            
            window.arcaeaDataLoader = new ArcaeaDataLoader();
            window.arcaeaDataLoader.initFromData(chartConstantData, songlistData);
            
            console.log('[Arcaea Helper] 数据已初始化');
          } catch (e) {
            console.error('[Arcaea Helper] 数据初始化失败:', e);
          }
        })();
      ''');
      debugPrint('[Arcaea Helper] 数据已初始化');

      // 5. 设置配置
      await controller.evaluateJavascript(source: '''
        window.arcaeaSettings = {
          showCharts: $showCharts,
          showConstant: $showConstant,
          showPTT: $showPTT,
          showTargetScore: $showTargetScore,
          showDownloadButtons: $showDownloadButtons,
        };
      ''');

      // 6. 注入主内容脚本
      await controller.evaluateJavascript(source: contentScript);
      debugPrint('[Arcaea Helper] 内容脚本已注入');

      // 7. 等待脚本初始化完成并主动触发页面处理
      bool triggeredViaReadyState = false;
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        
        final isReady = await controller.evaluateJavascript(source: '''
          (function() {
            return window.arcaeaHelperReady === true && 
                   typeof window.triggerProcessAllCards === 'function';
          })();
        ''');
        
        if (isReady == true) {
          debugPrint('[Arcaea Helper] 脚本已就绪，开始触发处理 (尝试 ${i + 1})');
          
          await controller.evaluateJavascript(source: '''
            (function() {
              console.log('[Arcaea Helper Flutter] 主动触发页面处理');
              window.triggerProcessAllCards();
            })();
          ''');
          
          _hasTriggeredProcessing = true;
          triggeredViaReadyState = true;
          debugPrint('[Arcaea Helper] ✅ 脚本注入完成并已触发');
          break;
        }
      }
      
      // 如果等待超时，仍然尝试触发
      if (!triggeredViaReadyState) {
        debugPrint('[Arcaea Helper] ⚠️ 脚本就绪检测超时，强制触发');
        final forced = await controller.evaluateJavascript(source: '''
          (function() {
            if (typeof window.triggerProcessAllCards === 'function') {
              console.log('[Arcaea Helper Flutter] 强制触发页面处理');
              window.triggerProcessAllCards();
              return true;
            } else {
              console.error('[Arcaea Helper Flutter] triggerProcessAllCards 函数不存在');
              return false;
            }
          })();
        ''');

        if (forced == true) {
          _hasTriggeredProcessing = true;
        }
      }

      debugPrint('[Arcaea Helper] ✅ 脚本注入完成');
      _hasInjectedScript = true;
    } catch (e, stackTrace) {
      debugPrint('[Arcaea Helper] ❌ 脚本注入失败: $e');
      debugPrint('[Arcaea Helper] 堆栈: $stackTrace');
    }
  }

  Future<void> _ensureScriptTriggered(InAppWebViewController controller) async {
    if (_hasTriggeredProcessing) {
      debugPrint('[Arcaea Helper] 已经触发过处理，跳过');
      return;
    }
    
    try {
      // 检查DOM是否有内容
      final hasContent = await controller.evaluateJavascript(source: '''
        (function() {
          const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
          const hasCards = Array.from(cardLists).some(list => 
            list.querySelectorAll('[data-v-b3942f14].card').length > 0
          );
          return hasCards;
        })();
      ''');
      
      if (hasContent != true) {
        debugPrint('[Arcaea Helper] DOM内容尚未准备好');
        return;
      }
      
      final isReady = await controller.evaluateJavascript(source: '''
        (function() {
          return window.arcaeaHelperReady === true && 
                 typeof window.triggerProcessAllCards === 'function';
        })();
      ''');
      
      if (isReady == true) {
        debugPrint('[Arcaea Helper] ✅ 触发页面处理');
        await controller.evaluateJavascript(source: '''
          (function() {
            console.log('[Arcaea Helper Flutter] 触发页面处理');
            window.triggerProcessAllCards();
          })();
        ''');
        _hasTriggeredProcessing = true;
      } else {
        debugPrint('[Arcaea Helper] 脚本尚未就绪');
      }
    } catch (e) {
      debugPrint('[Arcaea Helper] 确保触发失败: $e');
    }
  }
  
  void _startContinuousCheck(InAppWebViewController controller) {
    // 为iOS启动持续检查机制
    debugPrint('[Arcaea Helper] iOS: 启动持续检查机制');
    
    void checkAndTrigger() async {
      if (!_hasInjectedScript) {
        debugPrint('[Arcaea Helper] iOS: 脚本尚未注入，等待...');
        return;
      }
      
      if (_hasTriggeredProcessing) {
        debugPrint('[Arcaea Helper] iOS: 已触发处理，停止检查');
        return;
      }
      
      await _ensureScriptTriggered(controller);
    }
    
    // 延迟检查：500ms, 1s, 1.5s, 2s, 2.5s, 3s, 4s, 5s
    final delays = [500, 1000, 1500, 2000, 2500, 3000, 4000, 5000];
    for (final delay in delays) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted && !_hasTriggeredProcessing) {
          checkAndTrigger();
        }
      });
    }
  }
}
