import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arcaea Helper'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
                
                // iOS平台启动持续检查机制
                if (defaultTargetPlatform == TargetPlatform.iOS) {
                  _startContinuousCheck(controller);
                }
              },
              onLoadStart: (controller, url) {
                debugPrint('[WebView] 开始加载: $url');
                setState(() {
                  currentUrl = url?.toString() ?? '';
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

                // 检查是否是目标页面
                if (url.toString().contains('arcaea.lowiro.com') &&
                    url.toString().contains('/profile/potential')) {
                  debugPrint('[WebView] 检测到目标页面，开始注入脚本');
                  _hasInjectedScript = false;
                  _hasTriggeredProcessing = false;
                  await _injectArcaeaHelper(controller);
                  
                  // Android平台在这里已经可以工作，但iOS需要额外处理
                  if (defaultTargetPlatform == TargetPlatform.android) {
                    // Android可以立即触发
                    await Future.delayed(const Duration(milliseconds: 500));
                    await _ensureScriptTriggered(controller);
                  }
                }
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint(
                    '[WebView Console] ${consoleMessage.messageLevel}: ${consoleMessage.message}');
              },
              onReceivedError: (controller, request, error) {
                debugPrint('[WebView Error] URL: ${request.url}, Error: ${error.description}, Type: ${error.type}');
              },
              onReceivedHttpError: (controller, request, response) {
                debugPrint('[WebView HTTP Error] URL: ${request.url}, Status: ${response.statusCode}');
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
            color: Colors.black.withOpacity(0.1),
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

  Future<void> _injectArcaeaHelper(InAppWebViewController controller) async {
    try {
      debugPrint('[Arcaea Helper] 开始注入脚本...');
      
      // 加载核心模块
      final calculator =
          await _loadAssetAsString('web/js/arcaea-calculator.js');
      final dataLoader =
          await _loadAssetAsString('web/js/arcaea-data-loader.js');
      final contentScript =
          await _loadAssetAsString('web/js/flutter-content.js');
      final styles =
          await _loadAssetAsString('web/css/arcaea-styles.css');
      final chartConstant =
          await _loadAssetAsString('assets/data/ChartConstant.json');
      final songlist =
          await _loadAssetAsString('assets/data/Songlist.json');

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
          
          debugPrint('[Arcaea Helper] ✅ 脚本注入完成并已触发');
          return;
        }
      }
      
      // 如果等待超时，仍然尝试触发
      debugPrint('[Arcaea Helper] ⚠️ 脚本就绪检测超时，强制触发');
      await controller.evaluateJavascript(source: '''
        (function() {
          if (typeof window.triggerProcessAllCards === 'function') {
            console.log('[Arcaea Helper Flutter] 强制触发页面处理');
            window.triggerProcessAllCards();
          } else {
            console.error('[Arcaea Helper Flutter] triggerProcessAllCards 函数不存在');
          }
        })();
      ''');

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
