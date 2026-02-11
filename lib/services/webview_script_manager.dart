import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/constants.dart';
import '../models/b30r10_data.dart';
import 'b30r10_page_extractor.dart';

/// WebView 页面状态（原脚本注入已移除，改为 Flutter 侧数据提取）
class InjectionState {
  bool isTargetPage = false;
  DateTime? lastTargetPageTime;

  void reset() {
    isTargetPage = false;
    lastTargetPageTime = null;
  }
}

/// WebView 页面管理器
/// 不再注入任何 JS 脚本，通过 B30R10PageExtractor 在 Flutter 侧获取并处理页面数据
class WebViewScriptManager {
  final B30R10PageExtractor _extractor;
  final InjectionState _state = InjectionState();
  Timer? _targetPageGraceTimer;

  final void Function(B30R10Data data)? onB30R10DataReceived;
  final void Function(String message)? onDebugMessage;

  WebViewScriptManager({
    this.onB30R10DataReceived,
    this.onDebugMessage,
  }) : _extractor = B30R10PageExtractor(onDebugMessage: onDebugMessage);

  InjectionState get state => _state;

  /// 判断 URL 是否为目标 PTT 页面
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

  /// 判断 URL 是否为登录页面（带重定向参数）
  /// 登录页面可能会重定向回目标页面，所以不应该清除 isTargetPage 状态
  bool isLoginPageWithRedirect(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return false;
    try {
      final uri = Uri.parse(rawUrl);
      // 检查是否是登录页面且包含 redirect-path 参数
      final isLoginPage = uri.path.contains('/login') || uri.path.contains('/zh/login');
      final hasRedirect = uri.queryParameters.containsKey('redirect-path') ||
          rawUrl.contains('redirect-path');
      return uri.host.contains(AppConstants.arcaeaHost) && isLoginPage && hasRedirect;
    } catch (_) {
      return rawUrl.contains(AppConstants.arcaeaHost) &&
          (rawUrl.contains('/login') || rawUrl.contains('/zh/login')) &&
          rawUrl.contains('redirect-path');
    }
  }

  /// 检查页面 DOM 是否已就绪（卡片是否加载且内容已渲染）
  Future<bool> checkDOMReady(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(source: '''
        (function() {
          // 策略1：通过 card-list 容器查找卡片
          const lists = document.querySelectorAll('.card-list, [class*="card-list"]');
          
          // 策略2：直接查找所有 .card 类元素（不依赖 data-v 属性）
          const allCards = document.querySelectorAll('.card');
          
          // 策略3：查找包含分数的元素
          const scoreElements = document.querySelectorAll('.ex-main, [class*="ex-main"], .score');
          
          // 检查是否有包含分数内容的卡片
          function hasRenderedCards(cards) {
            for (const card of cards) {
              const text = card.innerText || '';
              const hasScore = /\\d{1,3}(,\\d{3}){2}/.test(text) || /\\d{7,8}/.test(text);
              const hasDiff = /FTR|BYD|PRS|PST|ETR|FUTURE|BEYOND|PRESENT|PAST|ETERNAL/i.test(text);
              if (hasScore && hasDiff) return true;
            }
            return false;
          }
          
          // 依次检查各种容器中的卡片
          if (lists.length > 0) {
            for (const list of lists) {
              let cards = list.querySelectorAll('.card');
              if (hasRenderedCards(cards)) return true;
            }
          }
          
          // 直接在全局范围查找
          if (hasRenderedCards(allCards)) return true;
          
          // 检查分数元素是否存在且有内容
          for (const el of scoreElements) {
            const text = (el.textContent || '').trim();
            if (/\\d{7,8}/.test(text) || /\\d{1,3}(,\\d{3}){2}/.test(text)) return true;
          }
          
          return false;
        })();
      ''');
      return result == true;
    } catch (e) {
      onDebugMessage?.call('DOM 就绪检查失败: $e');
      return false;
    }
  }

  /// 导出 B30/R10 数据（供图片生成等使用）
  /// 通过提取器从页面获取数据，无脚本注入
  Future<void> exportB30R10Data(InAppWebViewController controller) async {
    await extractB30R10Data(controller);
  }

  /// 从当前页面提取 B30/R10 数据（无脚本注入，仅在 Flutter 侧处理）
  Future<B30R10Data?> extractB30R10Data(InAppWebViewController controller) async {
    try {
      final data = await _extractor.extractFromPage(controller);
      if (data != null) {
        onB30R10DataReceived?.call(data);
      }
      return data;
    } catch (e) {
      onDebugMessage?.call('提取 B30/R10 数据失败: $e');
      rethrow;
    }
  }

  /// 启动目标页面宽限期定时器
  void startTargetPageGraceTimer(VoidCallback onGraceExpired) {
    _targetPageGraceTimer?.cancel();
    _state.lastTargetPageTime = DateTime.now();
    _targetPageGraceTimer = Timer(AppConstants.targetPageGracePeriod, () {
      if (!_state.isTargetPage) {
        onDebugMessage?.call('宽限期结束，确认离开目标页面');
        onGraceExpired();
      }
    });
  }

  /// 取消目标页面宽限期定时器
  void cancelTargetPageGraceTimer() {
    _targetPageGraceTimer?.cancel();
    _targetPageGraceTimer = null;
  }

  /// 重置状态
  void resetInjectionState() {
    _state.reset();
    cancelTargetPageGraceTimer();
  }

  void dispose() {
    cancelTargetPageGraceTimer();
  }
}
