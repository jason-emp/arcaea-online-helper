import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/constants.dart';
import '../models/app_settings.dart';
import '../models/b30r10_data.dart';

/// WebView注入状态
class InjectionState {
  bool hasInjectedScript = false;
  bool hasTriggeredProcessing = false;
  bool isTargetPage = false;
  int aggressiveAttempts = 0;
  bool aggressiveLoopActive = false;
  bool isPerformingAggressiveCycle = false;
  DateTime? lastTargetPageTime;

  void reset() {
    hasInjectedScript = false;
    hasTriggeredProcessing = false;
    isTargetPage = false;
    aggressiveAttempts = 0;
    aggressiveLoopActive = false;
    isPerformingAggressiveCycle = false;
    lastTargetPageTime = null;
  }
}

/// WebView脚本管理器
class WebViewScriptManager {
  // 缓存的脚本和资源
  String? _cachedCalculatorScript;
  String? _cachedDataLoaderScript;
  String? _cachedContentScript;
  String? _cachedStyles;
  String? _cachedChartConstant;
  String? _cachedSonglist;

  final InjectionState _state = InjectionState();
  Timer? _aggressiveTimer;
  Timer? _targetPageGraceTimer;

  // 回调函数
  final void Function(B30R10Data data)? onB30R10DataReceived;
  final void Function(String message)? onDebugMessage;

  WebViewScriptManager({
    this.onB30R10DataReceived,
    this.onDebugMessage,
  });

  InjectionState get state => _state;

  /// 预加载所有脚本和资源
  Future<void> preloadAssets() async {
    _cachedCalculatorScript ??= await rootBundle.loadString(AppConstants.calculatorScriptPath);
    _cachedDataLoaderScript ??= await rootBundle.loadString(AppConstants.dataLoaderScriptPath);
    _cachedContentScript ??= await rootBundle.loadString(AppConstants.contentScriptPath);
    _cachedStyles ??= await rootBundle.loadString(AppConstants.stylesPath);
    _cachedChartConstant ??= await rootBundle.loadString(AppConstants.chartConstantPath);
    _cachedSonglist ??= await rootBundle.loadString(AppConstants.songlistPath);
  }

  /// 判断URL是否为目标页面
  bool isTargetUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return false;

    try {
      final uri = Uri.parse(rawUrl);
      return uri.host.contains(AppConstants.arcaeaHost) &&
          uri.path.contains(AppConstants.profilePotentialPath);
    } catch (_) {
      return rawUrl.contains(AppConstants.arcaeaHost) &&
          rawUrl.contains(AppConstants.profilePotentialPath);
    }
  }

  /// 处理B30/R10数据导出
  void handleB30R10DataExport(List<dynamic> args) {
    scheduleMicrotask(() {
      try {
        Map<String, dynamic> jsonData;

        if (args[0] is String) {
          _log('iOS: 解析JSON字符串');
          final jsonString = args[0] as String;
          jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        } else if (args[0] is Map) {
          _log('Android: 使用Map对象');
          jsonData = args[0] as Map<String, dynamic>;
        } else {
          _log('未知数据类型: ${args[0].runtimeType}');
          return;
        }

        final data = B30R10Data.fromJson(jsonData);
        _log('数据已解析: ${data.player.username}');
        onB30R10DataReceived?.call(data);
      } catch (e, stackTrace) {
        _log('解析数据失败: $e\n堆栈: $stackTrace');
      }
    });
  }

  /// 注入Arcaea Helper脚本
  Future<void> injectScripts(
    InAppWebViewController controller,
    AppSettings settings,
  ) async {
    try {
      _log('====== 开始注入脚本 ======');

      await preloadAssets();

      // 1. 注入样式
      await controller.evaluateJavascript(source: '''
        (function() {
          if (!document.getElementById('arcaea-helper-styles')) {
            const style = document.createElement('style');
            style.id = 'arcaea-helper-styles';
            style.textContent = `$_cachedStyles`;
            document.head.appendChild(style);
            console.log('[Arcaea Helper] 样式已注入');
          }
        })();
      ''');
      _log('✅ 样式模块已注入');

      // 2. 注入核心计算模块
      await controller.evaluateJavascript(source: _cachedCalculatorScript!);
      _log('✅ 计算模块已注入');

      // 3. 注入数据加载模块
      await controller.evaluateJavascript(source: _cachedDataLoaderScript!);
      _log('✅ 数据加载模块已注入');

      // 4. 初始化数据
      await controller.evaluateJavascript(source: '''
        (function() {
          try {
            const chartConstantData = $_cachedChartConstant;
            const songlistData = $_cachedSonglist;
            
            window.arcaeaDataLoader = new ArcaeaDataLoader();
            window.arcaeaDataLoader.initFromData(chartConstantData, songlistData);
            
            console.log('[Arcaea Helper] 数据已初始化');
          } catch (e) {
            console.error('[Arcaea Helper] 数据初始化失败:', e);
          }
        })();
      ''');
      _log('✅ 数据已初始化');

      // 5. 设置配置
      await controller.evaluateJavascript(
        source: 'window.arcaeaSettings = ${settings.toJavaScriptObject()};',
      );
      _log('✅ 配置已设置');

      // 6. 注入主内容脚本
      await controller.evaluateJavascript(source: _cachedContentScript!);
      _log('✅ 内容脚本已注入');

      // 7. 等待脚本就绪并触发处理
      await _waitForScriptReadyAndTrigger(controller);

      _state.hasInjectedScript = true;
      _log('✅ 脚本注入完成');
    } catch (e, stackTrace) {
      _log('❌ 脚本注入失败: $e\n堆栈: $stackTrace');
    }
  }

  /// 等待脚本就绪并触发处理
  Future<void> _waitForScriptReadyAndTrigger(InAppWebViewController controller) async {
    bool triggered = false;

    for (int i = 0; i < AppConstants.maxReadyCheckAttempts; i++) {
      await Future.delayed(AppConstants.readyCheckInterval);

      final isReady = await controller.evaluateJavascript(source: '''
        (function() {
          return window.arcaeaHelperReady === true && 
                 typeof window.triggerProcessAllCards === 'function';
        })();
      ''');

      if (isReady == true) {
        _log('脚本已就绪，开始触发处理 (尝试 ${i + 1})');

        await controller.evaluateJavascript(source: '''
          (function() {
            console.log('[Arcaea Helper Flutter] 主动触发页面处理');
            window.triggerProcessAllCards();
          })();
        ''');

        _state.hasTriggeredProcessing = true;
        triggered = true;
        break;
      }
    }

    // 如果等待超时，强制触发
    if (!triggered) {
      _log('⚠️ 脚本就绪检测超时，强制触发');
      final forced = await controller.evaluateJavascript(source: '''
        (function() {
          if (typeof window.triggerProcessAllCards === 'function') {
            console.log('[Arcaea Helper Flutter] 强制触发页面处理');
            window.triggerProcessAllCards();
            return true;
          }
          return false;
        })();
      ''');

      if (forced == true) {
        _state.hasTriggeredProcessing = true;
      }
    }
  }

  /// 应用设置到WebView
  Future<void> applySettings(
    InAppWebViewController controller,
    AppSettings settings,
  ) async {
    await controller.evaluateJavascript(source: '''
      (function() {
        if (typeof window.applySettings === 'function') {
          window.applySettings(${settings.toJavaScriptObject()});
          console.log('[Arcaea Helper Flutter] 设置已更新');
        } else {
          console.warn('[Arcaea Helper Flutter] applySettings 函数未找到');
        }
      })();
    ''');
  }

  /// 检查DOM是否就绪
  Future<bool> checkDOMReady(InAppWebViewController controller) async {
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
      _log('DOM就绪检查失败: $e');
      return false;
    }
  }

  /// 确保脚本已触发
  Future<void> ensureScriptTriggered(InAppWebViewController controller) async {
    if (_state.hasTriggeredProcessing) return;

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
        if (!hasCards) return;
      }

      final isReady = await controller.evaluateJavascript(source: '''
        (function() {
          return window.arcaeaHelperReady === true && 
                 typeof window.triggerProcessAllCards === 'function';
        })();
      ''');

      if (isReady == true) {
        _log('✅ 触发页面处理 (尝试 ${_state.aggressiveAttempts})');
        await controller.evaluateJavascript(source: '''
          (function() {
            console.log('[Arcaea Helper Flutter] 触发页面处理');
            window.triggerProcessAllCards();
          })();
        ''');
        _state.hasTriggeredProcessing = true;
      }
    } catch (e) {
      _log('确保触发失败: $e');
    }
  }

  /// 启动激进注入循环
  void startAggressiveInjectionLoop(
    InAppWebViewController controller,
    AppSettings settings, {
    String reason = 'manual',
    bool forceRestart = false,
  }) {
    if (!_state.isTargetPage) return;
    if (_state.aggressiveLoopActive && !forceRestart) return;

    if (forceRestart) {
      stopAggressiveLoop();
    }

    _log('启动激进注入循环 ($reason)');
    _state.aggressiveAttempts = 0;
    _state.aggressiveLoopActive = true;

    unawaited(_performAggressiveInjectionStep(controller, settings, reason: 'initial-$reason'));

    _aggressiveTimer?.cancel();
    _aggressiveTimer = Timer.periodic(AppConstants.aggressiveInterval, (_) {
      unawaited(_performAggressiveInjectionStep(controller, settings, reason: 'timer-$reason'));
    });

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _startContinuousCheck(controller);
    }
  }

  /// 执行激进注入步骤
  Future<void> _performAggressiveInjectionStep(
    InAppWebViewController controller,
    AppSettings settings, {
    String reason = '',
  }) async {
    if (_state.isPerformingAggressiveCycle) return;
    if (!_state.isTargetPage) {
      stopAggressiveLoop();
      return;
    }
    if (_state.hasInjectedScript && _state.hasTriggeredProcessing) {
      stopAggressiveLoop();
      return;
    }

    _state.isPerformingAggressiveCycle = true;
    _state.aggressiveAttempts++;

    try {
      if (!_state.hasInjectedScript) {
        await injectScripts(controller, settings);
      } else {
        await ensureScriptTriggered(controller);
      }
    } catch (e, stackTrace) {
      _log('激进注入循环错误($reason): $e\n堆栈: $stackTrace');
    } finally {
      _state.isPerformingAggressiveCycle = false;
    }

    if (_state.hasInjectedScript && _state.hasTriggeredProcessing) {
      _log('激进注入循环完成');
      stopAggressiveLoop();
      return;
    }

    if (_state.aggressiveAttempts >= AppConstants.maxAggressiveAttempts) {
      _log('激进注入循环达到上限 ($reason)');
      stopAggressiveLoop();
    }
  }

  /// 停止激进注入循环
  void stopAggressiveLoop() {
    _aggressiveTimer?.cancel();
    _aggressiveTimer = null;
    _state.aggressiveLoopActive = false;
    _state.isPerformingAggressiveCycle = false;
  }

  /// iOS持续检查机制
  void _startContinuousCheck(InAppWebViewController controller) {
    _log('iOS: 启动增强持续检查机制');

    void checkAndTrigger() async {
      if (!_state.isTargetPage) return;
      if (!_state.hasInjectedScript) {
        _log('iOS: 脚本尚未注入，等待...');
        return;
      }
      if (_state.hasTriggeredProcessing) return;

      try {
        final hasContent = await controller.evaluateJavascript(source: '''
          (function() {
            const hasBody = document.body && document.body.children.length > 0;
            const hasCards = document.querySelectorAll('.card-list, [class*="card-list"]').length > 0;
            return hasBody || hasCards;
          })();
        ''');

        if (hasContent == true) {
          _log('iOS: 检测到内容，尝试触发处理');
          await ensureScriptTriggered(controller);
        }
      } catch (e) {
        _log('iOS: 检查失败: $e');
      }
    }

    for (final delay in AppConstants.iosContinuousCheckDelays) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (!_state.hasTriggeredProcessing && _state.isTargetPage) {
          checkAndTrigger();
        }
      });
    }
  }

  /// 启动目标页面宽限期定时器
  void startTargetPageGraceTimer(VoidCallback onGraceExpired) {
    _targetPageGraceTimer?.cancel();
    _state.lastTargetPageTime = DateTime.now();

    _targetPageGraceTimer = Timer(AppConstants.targetPageGracePeriod, () {
      if (!_state.isTargetPage) {
        _log('宽限期结束，确认离开目标页面');
        onGraceExpired();
      }
    });
  }

  /// 取消目标页面宽限期定时器
  void cancelTargetPageGraceTimer() {
    _targetPageGraceTimer?.cancel();
  }

  /// 导出B30/R10数据
  Future<void> exportB30R10Data(InAppWebViewController controller) async {
    try {
      _log('开始获取B30/R10数据...');

      await controller.evaluateJavascript(source: '''
        (function() {
          setTimeout(async function() {
            try {
              if (typeof window.exportB30R10Data === 'function') {
                const data = await window.exportB30R10Data();
                if (data) {
                  try {
                    window.flutter_inappwebview.callHandler('${AppConstants.exportB30R10DataHandler}', data);
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
      _log('获取数据失败: $e\n堆栈: $stackTrace');
      rethrow;
    }
  }

  /// 重置注入状态
  void resetInjectionState() {
    _state.reset();
    stopAggressiveLoop();
    cancelTargetPageGraceTimer();
  }

  /// 清理资源
  void dispose() {
    stopAggressiveLoop();
    cancelTargetPageGraceTimer();
  }

  void _log(String message) {
    onDebugMessage?.call(message);
  }
}
