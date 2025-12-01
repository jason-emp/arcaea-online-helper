import 'dart:async';
import 'dart:convert';
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
  static const int _maxAggressiveAttempts = 150;  // 增加到150次
  static const Duration _aggressiveInterval = Duration(milliseconds: 400);  // 增加到400ms

  String? _cachedCalculatorScript;
  String? _cachedDataLoaderScript;
  String? _cachedContentScript;
  String? _cachedStyles;
  String? _cachedChartConstant;
  String? _cachedSonglist;

  // 用于处理页面刷新时的临时跳转
  DateTime? _lastTargetPageTime;
  Timer? _targetPageGraceTimer;

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
    _targetPageGraceTimer?.cancel();
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
                  callback: (args) {
                    debugPrint('[Arcaea Helper] 接收到B30/R10数据');
                    
                    // 使用scheduleMicrotask在主isolate中异步处理
                    scheduleMicrotask(() {
                      try {
                        // 数据可能是JSON字符串(iOS)或Map(Android)
                        Map<String, dynamic> jsonData;
                        
                        if (args[0] is String) {
                          // iOS: 解析JSON字符串
                          debugPrint('[Arcaea Helper] iOS: 解析JSON字符串');
                          final jsonString = args[0] as String;
                          jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
                        } else if (args[0] is Map) {
                          // Android: 直接使用Map
                          debugPrint('[Arcaea Helper] Android: 使用Map对象');
                          jsonData = args[0] as Map<String, dynamic>;
                        } else {
                          debugPrint('[Arcaea Helper] 未知数据类型: ${args[0].runtimeType}');
                          return;
                        }
                        
                        _cachedB30R10Data = B30R10Data.fromJson(jsonData);
                        debugPrint('[Arcaea Helper] 数据已缓存: ${_cachedB30R10Data!.player.username}');
                        
                        // 使用WidgetsBinding确保在主线程显示SnackBar
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('数据已准备: ${_cachedB30R10Data!.player.username}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        });
                      } catch (e, stackTrace) {
                        debugPrint('[Arcaea Helper] 解析数据失败: $e');
                        debugPrint('[Arcaea Helper] 堆栈: $stackTrace');
                      }
                    });
                    
                    // 立即返回null，不等待异步操作
                    return null;
                  },
                );
              },
              onLoadStart: (controller, url) {
                debugPrint('[WebView] 开始加载: $url');
                final rawUrl = url?.toString();
                final wasTargetPage = _isTargetPage;
                final isTarget = _isTargetUrl(rawUrl);
                
                // 如果是目标页面的加载开始,立即重置注入状态以确保刷新后能重新注入
                if (isTarget) {
                  debugPrint('[Arcaea Helper] 检测到目标页面开始加载，重置注入状态');
                  _hasInjectedScript = false;
                  _hasTriggeredProcessing = false;
                  _aggressiveAttempts = 0;
                  _stopAggressiveLoop();
                  _targetPageGraceTimer?.cancel();
                  _isTargetPage = true;
                }
                // 如果从目标页离开,设置宽限期
                else if (wasTargetPage && !isTarget) {
                  debugPrint('[Arcaea Helper] 检测到离开目标页面，设置3秒宽限期');
                  _lastTargetPageTime = DateTime.now();
                  _targetPageGraceTimer?.cancel();
                  _targetPageGraceTimer = Timer(const Duration(seconds: 3), () {
                    // 3秒后如果还没回到目标页面，才真正重置
                    if (!_isTargetPage && mounted) {
                      debugPrint('[Arcaea Helper] 宽限期结束，确认离开目标页面');
                      _resetInjectionState();
                    }
                  });
                  _isTargetPage = false;
                } else if (!wasTargetPage && isTarget) {
                  // 从非目标页回到目标页，取消宽限期
                  _targetPageGraceTimer?.cancel();
                  debugPrint('[Arcaea Helper] 回到目标页面，取消宽限期');
                  _isTargetPage = true;
                }
                
                debugPrint('[Arcaea Helper] URL检测: isTarget=$_isTargetPage, url=$rawUrl');
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
              onUpdateVisitedHistory: (controller, url, isReload) async {
                final urlString = url?.toString() ?? '';
                final isTarget = _isTargetUrl(urlString);
                
                debugPrint('[WebView] onUpdateVisitedHistory - url=$urlString, isReload=$isReload, isTarget=$isTarget');
                
                // 如果是刷新操作且是目标页面,强制重新注入
                if (isReload == true && isTarget) {
                  debugPrint('[Arcaea Helper] 检测到页面刷新,强制重置并重新注入');
                  _hasInjectedScript = false;
                  _hasTriggeredProcessing = false;
                  _aggressiveAttempts = 0;
                  _stopAggressiveLoop();
                  _targetPageGraceTimer?.cancel();
                  _isTargetPage = true;
                  _lastTargetPageTime = null;
                  
                  setState(() {
                    currentUrl = urlString;
                  });
                  
                  // 等待DOM加载
                  await Future.delayed(const Duration(milliseconds: 1000));
                  
                  // 检查DOM是否已就绪
                  final domReady = await _checkDOMReady(controller);
                  debugPrint('[Arcaea Helper] onUpdateVisitedHistory(刷新) - DOM就绪状态: $domReady');
                  
                  if (!domReady) {
                    debugPrint('[Arcaea Helper] onUpdateVisitedHistory(刷新) - DOM未就绪，再等待500ms');
                    await Future.delayed(const Duration(milliseconds: 500));
                  }
                  
                  debugPrint('[Arcaea Helper] onUpdateVisitedHistory(刷新) - 开始启动激进注入循环');
                  _startAggressiveInjectionLoop(controller, reason: 'reload', forceRestart: true);
                  return;
                }
                
                // 如果URL变成了目标页面(非刷新场景)
                if (isTarget) {
                  // 取消之前的宽限期定时器
                  _targetPageGraceTimer?.cancel();
                  
                  final now = DateTime.now();
                  final isQuickReturn = _lastTargetPageTime != null && 
                                       now.difference(_lastTargetPageTime!) < const Duration(seconds: 3);
                  
                  if (!_isTargetPage || isQuickReturn) {
                    debugPrint('[Arcaea Helper] onUpdateVisitedHistory 检测到URL变为目标页面，准备注入 (快速返回: $isQuickReturn)');
                    _isTargetPage = true;
                    setState(() {
                      currentUrl = urlString;
                    });
                    
                    // 如果是快速返回(可能是刷新后的登录跳转),重置注入状态
                    if (isQuickReturn) {
                      debugPrint('[Arcaea Helper] 快速返回场景,重置注入状态');
                      _hasInjectedScript = false;
                      _hasTriggeredProcessing = false;
                      _aggressiveAttempts = 0;
                      _stopAggressiveLoop();
                    }
                    
                    // 等待DOM加载
                    await Future.delayed(const Duration(milliseconds: 1000));
                    
                    // 检查DOM是否已就绪
                    final domReady = await _checkDOMReady(controller);
                    debugPrint('[Arcaea Helper] onUpdateVisitedHistory - DOM就绪状态: $domReady');
                    
                    if (!domReady) {
                      debugPrint('[Arcaea Helper] onUpdateVisitedHistory - DOM未就绪，再等待500ms');
                      await Future.delayed(const Duration(milliseconds: 500));
                    }
                    
                    debugPrint('[Arcaea Helper] onUpdateVisitedHistory - 开始启动激进注入循环');
                    _startAggressiveInjectionLoop(controller, reason: 'updateVisitedHistory', forceRestart: true);
                  }
                } else if (!isTarget && _isTargetPage) {
                  // 离开目标页面，但不立即停止，给予宽限期
                  debugPrint('[Arcaea Helper] onUpdateVisitedHistory 检测到离开目标页面，等待宽限期');
                  _lastTargetPageTime = DateTime.now();
                  
                  // 不立即设置 _isTargetPage = false，让宽限期定时器处理
                  // 注意:不在这里重置 _isTargetPage,以避免中断正在进行的注入
                }
              },
              onLoadStop: (controller, url) async {
                final urlString = url?.toString() ?? '';
                debugPrint('[WebView] 加载完成: $urlString');
                setState(() {
                  progress = 1.0;
                });

                final isTarget = _isTargetUrl(urlString);
                debugPrint('[Arcaea Helper] onLoadStop - isTarget=$isTarget, url=$urlString');
                _isTargetPage = isTarget;
                
                if (isTarget) {
                  debugPrint('[Arcaea Helper] 检测到目标页面，延迟800ms后开始注入');
                  // 延迟更长时间以确保DOM完全加载和渲染
                  await Future.delayed(const Duration(milliseconds: 800));
                  
                  // 检查DOM是否已就绪
                  final domReady = await _checkDOMReady(controller);
                  debugPrint('[Arcaea Helper] DOM就绪状态: $domReady');
                  
                  // 如果DOM未就绪，再等待一会儿
                  if (!domReady) {
                    debugPrint('[Arcaea Helper] DOM未就绪，再等待500ms');
                    await Future.delayed(const Duration(milliseconds: 500));
                  }
                  
                  debugPrint('[Arcaea Helper] 开始启动激进注入循环');
                  _startAggressiveInjectionLoop(controller, reason: 'loadStop', forceRestart: true);
                } else {
                  debugPrint('[Arcaea Helper] 非目标页面，停止注入循环');
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
      
      // iOS崩溃的根本原因：callHandler返回值处理
      // 解决方案：使用setTimeout延迟执行，不处理返回值
      await webViewController!.evaluateJavascript(source: '''
        (function() {
          setTimeout(async function() {
            try {
              if (typeof window.exportB30R10Data === 'function') {
                const data = await window.exportB30R10Data();
                if (data) {
                  // 发送数据，但不等待返回值，也不处理promise
                  try {
                    window.flutter_inappwebview.callHandler('exportB30R10Data', data);
                    console.log('[Arcaea Helper] 数据已发送到Flutter');
                  } catch (e) {
                    console.error('[Arcaea Helper] 调用handler失败:', e);
                  }
                } else {
                  console.error('[Arcaea Helper] 数据导出为空');
                }
              } else {
                console.error('[Arcaea Helper] exportB30R10Data 函数不存在');
              }
            } catch (error) {
              console.error('[Arcaea Helper] 导出过程出错:', error);
            }
          }, 100);
        })();
      ''');
    } catch (e, stackTrace) {
      debugPrint('[Arcaea Helper] 获取数据失败: $e');
      debugPrint('[Arcaea Helper] 堆栈: $stackTrace');
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
    _lastTargetPageTime = null;
    _targetPageGraceTimer?.cancel();
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
      debugPrint('[Arcaea Helper] ====== 开始注入脚本 ======');
      debugPrint('[Arcaea Helper] 当前 URL: $currentUrl');
      debugPrint('[Arcaea Helper] 是否目标页面: $_isTargetPage');

      // 加载核心模块
      await _ensureAssetsCached();
      final calculator = _cachedCalculatorScript!;
      final dataLoader = _cachedDataLoaderScript!;
      final contentScript = _cachedContentScript!;
      final styles = _cachedStyles!;
      final chartConstant = _cachedChartConstant!;
      final songlist = _cachedSonglist!;

      debugPrint('[Arcaea Helper] 资源加载完成，开始注入...');

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
      debugPrint('[Arcaea Helper] ✅ 样式模块已注入');

      // 2. 注入核心计算模块
      await controller.evaluateJavascript(source: calculator);
      debugPrint('[Arcaea Helper] ✅ 计算模块已注入');

      // 3. 注入数据加载模块
      await controller.evaluateJavascript(source: dataLoader);
      debugPrint('[Arcaea Helper] ✅ 数据加载模块已注入');

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
      debugPrint('[Arcaea Helper] ✅ 数据已初始化');

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
      debugPrint('[Arcaea Helper] ✅ 配置已设置');

      // 6. 注入主内容脚本
      await controller.evaluateJavascript(source: contentScript);
      debugPrint('[Arcaea Helper] ✅ 内容脚本已注入');

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
      return;
    }
    
    try {
      // 检查DOM是否有内容
      final domCheck = await controller.evaluateJavascript(source: '''
        (function() {
          const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
          let totalCards = 0;
          cardLists.forEach(list => {
            totalCards += list.querySelectorAll('[data-v-b3942f14].card').length;
          });
          return {
            hasCardLists: cardLists.length > 0,
            totalCards: totalCards,
            hasCards: totalCards > 0
          };
        })();
      ''');
      
      if (domCheck is Map) {
        final hasCards = domCheck['hasCards'] == true;
        final totalCards = domCheck['totalCards'] ?? 0;
        final hasCardLists = domCheck['hasCardLists'] == true;
        
        debugPrint('[Arcaea Helper] DOM检查: 卡片列表=$hasCardLists, 卡片数=$totalCards');
        
        if (!hasCards) {
          return;
        }
      } else if (domCheck != true) {
        return;
      }
      
      final isReady = await controller.evaluateJavascript(source: '''
        (function() {
          return window.arcaeaHelperReady === true && 
                 typeof window.triggerProcessAllCards === 'function';
        })();
      ''');
      
      if (isReady == true) {
        debugPrint('[Arcaea Helper] ✅ 触发页面处理 (尝试 $_aggressiveAttempts)');
        await controller.evaluateJavascript(source: '''
          (function() {
            console.log('[Arcaea Helper Flutter] 触发页面处理');
            window.triggerProcessAllCards();
          })();
        ''');
        _hasTriggeredProcessing = true;
      }
    } catch (e) {
      debugPrint('[Arcaea Helper] 确保触发失败: $e');
    }
  }
  
  Future<bool> _checkDOMReady(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(source: '''
        (function() {
          const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
          const hasCards = Array.from(cardLists).some(list => 
            list.querySelectorAll('[data-v-b3942f14].card').length > 0
          );
          return hasCards;
        })();
      ''');
      return result == true;
    } catch (e) {
      debugPrint('[Arcaea Helper] DOM就绪检查失败: $e');
      return false;
    }
  }
  
  void _startContinuousCheck(InAppWebViewController controller) {
    // 为iOS启动持续检查机制（增强版）
    debugPrint('[Arcaea Helper] iOS: 启动增强持续检查机制');
    
    void checkAndTrigger() async {
      if (!mounted || !_isTargetPage) {
        return;
      }
      
      if (!_hasInjectedScript) {
        debugPrint('[Arcaea Helper] iOS: 脚本尚未注入，等待...');
        return;
      }
      
      if (_hasTriggeredProcessing) {
        return;
      }
      
      // 检查DOM内容
      try {
        final hasContent = await controller.evaluateJavascript(source: '''
          (function() {
            const hasBody = document.body && document.body.children.length > 0;
            const hasCards = document.querySelectorAll('.card-list, [class*="card-list"]').length > 0;
            return hasBody || hasCards;
          })();
        ''');
        
        if (hasContent == true) {
          debugPrint('[Arcaea Helper] iOS: 检测到内容，尝试触发处理');
          await _ensureScriptTriggered(controller);
        } else {
          debugPrint('[Arcaea Helper] iOS: 内容未就绪');
        }
      } catch (e) {
        debugPrint('[Arcaea Helper] iOS: 检查失败: $e');
      }
    }
    
    // 延迟检查：使用更密集和更长时间的策略
    // 前期密集检查，后期稀疏检查，总时长延长到20秒
    final delays = [
      400, 800, 1200, 1600,  // 前2秒，每400ms
      2000, 2500, 3000,      // 2-3秒
      3500, 4000, 5000,      // 3-5秒  
      6000, 7000, 8000,      // 5-8秒
      10000, 12000, 15000, 20000  // 8-20秒
    ];
    
    for (final delay in delays) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted && !_hasTriggeredProcessing && _isTargetPage) {
          checkAndTrigger();
        }
      });
    }
  }
}
