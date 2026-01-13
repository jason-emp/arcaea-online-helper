import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/partner_data.dart';
import 'partner_storage_service.dart';

/// 搭档拉取服务
class PartnerFetchService {
  HeadlessInAppWebView? _headlessWebView;
  final _partnerStreamController =
      StreamController<List<PartnerData>>.broadcast();
  final _errorStreamController = StreamController<String>.broadcast();
  final _progressStreamController = StreamController<double>.broadcast();
  final _storageService = PartnerStorageService();

  Stream<List<PartnerData>> get partnerStream =>
      _partnerStreamController.stream;
  Stream<String> get errorStream => _errorStreamController.stream;
  Stream<double> get progressStream => _progressStreamController.stream;

  bool _isFetching = false;
  List<PartnerData> _allPartners = [];

  /// 初始化WebView
  Future<InAppWebViewController> _initializeWebView() async {
    final completer = Completer<InAppWebViewController>();
    // 初始页面
    const url = 'https://arcaea.lowiro.com/zh/profile/partners?page=1';

    // iOS 特定设置，防止 WebView 被过早释放
    final settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      // 启用 Cookie 共享，确保 HeadlessWebView 可以访问登录状态
      sharedCookiesEnabled: true,
      // iOS 特定设置
      allowsBackForwardNavigationGestures: false,
      isFraudulentWebsiteWarningEnabled: false,
      disableLongPressContextMenuOnLinks: true,
      allowsLinkPreview: false,
    );

    _headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: settings,
      onLoadStart: (controller, url) {
        print('[搭档获取] 页面开始加载: $url');
      },
      onLoadStop: (controller, url) async {
        print('[搭档获取] 页面加载完成: $url');
        if (!completer.isCompleted) {
          completer.complete(controller);
        }
      },
      onLoadError: (controller, url, code, message) {
        print('[搭档获取] 页面加载错误: $message');
        if (!completer.isCompleted) {
          completer.completeError('页面加载失败: $message');
        }
      },
    );

    await _headlessWebView!.run();
    
    // iOS 平台需要额外等待确保 WebView 稳定
    if (Platform.isIOS) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('初始化 WebView 超时，请检查网络连接');
      },
    );
  }

  Future<void> _cleanupWebView() async {
    if (_headlessWebView != null) {
      await _headlessWebView!.dispose();
      _headlessWebView = null;
    }
  }

  /// 开始拉取搭档
  Future<void> startFetching() async {
    if (_isFetching) {
      _errorStreamController.add('正在拉取中,请稍候');
      return;
    }

    _isFetching = true;
    _allPartners = [];

    try {
      print('[搭档获取] 开始初始化 WebView...');
      final controller = await _initializeWebView();
      print('[搭档获取] WebView 初始化完成');

      // 等待初始页面完全加载
      await _waitForPageLoad(controller);
      print('[搭档获取] 初始页面加载完成');

      int currentPage = 1;
      bool hasMore = true;

      // 循环翻页直到没有搭档
      while (hasMore && _isFetching) {
        print('[搭档获取] 正在处理第 $currentPage 页...');
        // 更新进度 (估算，假设大概10页)
        _progressStreamController.add((currentPage / 10.0).clamp(0.0, 0.95));

        // 如果不是第一页，需要跳转
        if (currentPage > 1) {
          final url =
              'https://arcaea.lowiro.com/zh/profile/partners?page=$currentPage';
          print('[搭档获取] 跳转到: $url');
          
          await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
          
          // 等待一小段时间让重定向发生
          await Future.delayed(const Duration(milliseconds: 500));
          
          // 轮询检测URL是否稳定
          String? lastUrl;
          bool urlStable = false;
          for (int i = 0; i < 10; i++) {
            final currentUrl = await controller.getUrl();
            final currentUrlStr = currentUrl?.toString() ?? '';
            print('[搭档获取] 当前URL检查 ($i): $currentUrlStr');
            
            if (lastUrl == currentUrlStr && currentUrlStr.isNotEmpty) {
              // URL稳定了，说明重定向完成
              urlStable = true;
              print('[搭档获取] URL已稳定');
              break;
            }
            lastUrl = currentUrlStr;
            await Future.delayed(const Duration(milliseconds: 300));
          }
          
          if (!urlStable) {
            print('[搭档获取] 警告: URL未稳定，但继续尝试');
          }
          
          await _waitForPageLoad(controller);
        }

        // 检查页面上是否有搭档
        final partnerCount = await _getPartnerCount(controller);
        print('[搭档获取] 第 $currentPage 页找到 $partnerCount 个搭档');
        if (partnerCount == 0) {
          hasMore = false;
          break;
        }

        // 逐个点击获取详情
        final pagePartners = await _fetchPagePartners(controller, partnerCount);
        if (pagePartners.isEmpty) {
          hasMore = false; // 页面有卡片但解析为空，可能是出错了或真没了
        } else {
          _allPartners.addAll(pagePartners);
          _partnerStreamController.add(_allPartners);
          
          // 保存到本地存储
          await _storageService.savePartners(_allPartners);
          
          currentPage++;
        }
      }

      _progressStreamController.add(1.0);
      print('[搭档获取] 完成！共获取 ${_allPartners.length} 个搭档');
    } catch (e) {
      _errorStreamController.add('拉取错误: $e');
    } finally {
      _isFetching = false;
      await _cleanupWebView();
    }
  }

  void stopFetching() {
    _isFetching = false;
  }

  /// 从缓存加载搭档数据
  Future<List<PartnerData>> loadCachedPartners() async {
    try {
      final partners = await _storageService.loadPartners();
      if (partners.isNotEmpty) {
        _allPartners = partners;
        _partnerStreamController.add(_allPartners);
      }
      return partners;
    } catch (e) {
      print('[搭档获取] 加载缓存失败: $e');
      return [];
    }
  }

  /// 获取最后更新时间
  Future<DateTime?> getLastUpdateTime() async {
    return await _storageService.getLastUpdateTime();
  }

  /// 清除搭档数据
  Future<void> clearPartnerData() async {
    await _storageService.clearPartners();
    _allPartners = [];
    _partnerStreamController.add([]);
  }

  Future<void> _waitForPageLoad(InAppWebViewController controller) async {
    // 等待页面加载并检查关键元素是否出现
    print('[搭档获取] 开始等待页面内容加载...');
    
    // iOS 平台增加初始等待时间
    if (Platform.isIOS) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    for (int i = 0; i < 25; i++) {
      // iOS 平台使用更长的等待间隔
      final waitDuration = Platform.isIOS 
          ? const Duration(milliseconds: 400) 
          : const Duration(milliseconds: 300);
      await Future.delayed(waitDuration);
      
      try {
        final result = await controller.evaluateJavascript(source: '''
          (function() {
            const list = document.querySelector('.list');
            const cards = list ? list.querySelectorAll('.card') : [];
            console.log('[页面检查] .list: ' + (list !== null) + ', cards: ' + cards.length);
            return list !== null && cards.length > 0;
          })();
        ''');
        if (result == true) {
          print('[搭档获取] 页面加载完成，找到 .list 元素和卡片');
          // iOS 平台增加更长的渲染等待时间
          final renderDelay = Platform.isIOS 
              ? const Duration(milliseconds: 1200) 
              : const Duration(milliseconds: 800);
          await Future.delayed(renderDelay);
          return;
        }
      } catch (e) {
        print('[搭档获取] 页面检查异常: $e');
        if (Platform.isIOS) {
          // iOS 上如果出现异常，可能是 WebView 被释放了
          break;
        }
      }
    }
    print('[搭档获取] 警告: 页面加载超时，未找到完整内容');
    // 即使超时也继续，可能是页面结构不同
  }

  Future<int> _getPartnerCount(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(source: '''
        (function() {
          // 尝试多个可能的选择器
          let cards = document.querySelectorAll('.list > .card');
          if (cards.length === 0) {
            cards = document.querySelectorAll('.list .card');
          }
          console.log('[搭档计数] 找到 ' + cards.length + ' 个卡片');
          return cards.length;
        })();
      ''');
      
      if (result == null) return 0;
      
      // 处理可能的不同返回类型
      if (result is int) return result;
      if (result is double) return result.toInt();
      
      // 字符串解析，处理可能的浮点数格式如 "6.0"
      final str = result.toString().trim();
      if (str.isEmpty) return 0;
      
      // 尝试解析为 double 然后转 int（处理 "6.0" 这种情况）
      final parsed = double.tryParse(str);
      final count = parsed?.toInt() ?? 0;
      
      print('[搭档获取] _getPartnerCount 返回: $count');
      return count;
    } catch (e) {
      print('[搭档获取] _getPartnerCount 出错: $e');
      return 0;
    }
  }

  Future<List<PartnerData>> _fetchPagePartners(
      InAppWebViewController controller, int count) async {
    List<PartnerData> partners = [];

    for (int i = 0; i < count; i++) {
      if (!_isFetching) break;
      
      // iOS 平台需要检查 WebView 是否仍然有效
      if (Platform.isIOS) {
        try {
          // 通过简单的 JS 调用来检查 WebView 是否仍然存活
          final isAlive = await controller.evaluateJavascript(source: 'true');
          if (isAlive != true) {
            print('[搭档获取] 警告: WebView 可能已失效，跳过剩余搭档');
            break;
          }
        } catch (e) {
          print('[搭档获取] 警告: WebView 检查失败: $e');
          break;
        }
        // iOS 上每次操作前增加小延迟，避免过快操作导致 WebView 被释放
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 1. 点击卡片并获取列表上的信息（如是否选中和头像URL）
      print('[搭档获取] 准备点击第 $i 个搭档卡片...');
      final cardInfoResult = await controller.evaluateJavascript(source: '''
        (function() {
          console.log('[卡片点击] 开始处理索引 $i');
          const cards = document.querySelectorAll('.list > .card, .list .card');
          if (cards.length > $i) {
            const card = cards[$i];
            console.log('[卡片点击] 找到卡片 $i');
            // 检查是否选中 (根据提供的HTML, .default 元素会有 .selected 类)
            const isSelected = card.querySelector('.default.selected') !== null;
            console.log('[卡片点击] isSelected: ' + isSelected);
            
            // 从列表卡片中提取头像URL（作为备用）
            let cardIconUrl = '';
            const imgInCard = card.querySelector('img.middle');
            if (imgInCard && imgInCard.src) {
              cardIconUrl = imgInCard.src;
              console.log('[卡片点击] 从卡片获取头像URL: ' + cardIconUrl);
            }
            
            card.click();
            console.log('[卡片点击] 已点击卡片 $i');
            return { 'isSelected': isSelected, 'cardIconUrl': cardIconUrl };
          }
          console.log('[卡片点击] 未找到索引为 $i 的卡片，总数: ' + cards.length);
          return null;
        })();
      ''');

      if (cardInfoResult == null) {
        print('[搭档获取] 警告: 第 $i 个卡片点击失败');
        continue;
      }
      print('[搭档获取] 第 $i 个卡片点击成功');
      final cardInfo = jsonDecode(jsonEncode(cardInfoResult));
      final bool isSelected = cardInfo['isSelected'] ?? false;
      final String cardIconUrl = cardInfo['cardIconUrl'] ?? '';

      // 2. 等待弹窗出现
      bool modalAppeared = false;
      for (int attempt = 0; attempt < 10; attempt++) {
        await Future.delayed(const Duration(milliseconds: 300));
        final checkModal = await controller.evaluateJavascript(source: '''
          document.querySelector('.modal-container') !== null;
        ''');
        if (checkModal == true) {
          modalAppeared = true;
          print('[搭档获取] 弹窗已出现');
          break;
        }
      }
      
      if (!modalAppeared) {
        print('[搭档获取] 警告: 弹窗未出现，跳过第 $i 个搭档');
        continue;
      }

      // 3. 解析数据
      final parseScript = '''
        (function() {
          try {
            const modal = document.querySelector('.modal-container');
            if (!modal) return null;

            const nameEl = modal.querySelector('.head-character h1');
            const name = nameEl ? nameEl.textContent.trim() : '';

            const levelEl = modal.querySelector('.section-1 .level span');
            const level = levelEl ? parseInt(levelEl.textContent) : 0;

            const typeEl = modal.querySelector('.score.type .number');
            const type = typeEl ? typeEl.textContent.trim() : '';

            // Stats
            // 根据 HTML 结构定位
            // Left Frame: Type, Step
            // Right Frame: Frag, Overdrive
            // 假设 .frame 顺序固定
            
            const frames = modal.querySelectorAll('.partner-character .frame');
            let step = 0;
            let frag = 0;
            let overdrive = 0;

            if (frames.length >= 2) {
               // Left frame (index 0 or class 'left')
               const leftFrame = frames[0]; // has Type and Step
               // Step is usually the second .score in the first frame based on HTML provided
               const stepScore = leftFrame.querySelectorAll('.score')[1];
               if (stepScore) step = parseInt(stepScore.querySelector('.number').textContent) || 0;

               // Right frame (index 1)
               const rightFrame = frames[1]; 
               // Frag is 1st, Overdrive is 2nd
               const scoresRight = rightFrame.querySelectorAll('.score');
               if (scoresRight.length >= 2) {
                 frag = parseInt(scoresRight[0].querySelector('.number').textContent) || 0;
                 overdrive = parseInt(scoresRight[1].querySelector('.number').textContent) || 0;
               }
            }
            
            const skillEl = modal.querySelector('.partner-character .text.zh');
            const skill = skillEl ? skillEl.textContent.trim() : '';

            // Icon URL - 尝试多种方式获取
            // 方式1: 从 .character 的 background-image
            const charDiv = modal.querySelector('.character');
            let iconUrl = '';
            if (charDiv) {
               const bg = window.getComputedStyle(charDiv).backgroundImage;
               const match = bg.match(/url\\(["']?(.*?)["']?\\)/);
               if (match && match[1]) {
                 iconUrl = match[1];
                 console.log('[解析] 从弹窗background获取头像: ' + iconUrl);
               }
            }
            
            // 方式2: 如果方式1失败，尝试从img标签获取
            if (!iconUrl) {
              const imgEl = modal.querySelector('img[src*="webassets"], img[src*="chr"]');
              if (imgEl && imgEl.src) {
                iconUrl = imgEl.src;
                console.log('[解析] 从弹窗img标签获取头像: ' + iconUrl);
              }
            }
            
            return {
              'name': name,
              'level': level,
              'iconUrl': iconUrl,
              'type': type,
              'step': step,
              'frag': frag,
              'overdrive': overdrive,
              'skill': skill
            };
          } catch(e) {
            return null;
          }
        })();
      ''';

      final result = await controller.evaluateJavascript(source: parseScript);

      if (result != null) {
        print('[搭档获取] 成功解析第 $i 个搭档数据');
        final data = jsonDecode(jsonEncode(result)); // Ensure Map
        data['isSelected'] = isSelected; // Merge isSelected
        
        // 如果弹窗中没有获取到头像URL，使用从卡片获取的URL
        if ((data['iconUrl'] == null || data['iconUrl'].isEmpty) && cardIconUrl.isNotEmpty) {
          data['iconUrl'] = cardIconUrl;
          print('[搭档获取] 使用卡片头像URL作为备用: $cardIconUrl');
        }
        
        final partner = PartnerData.fromJson(data);
        print('[搭档获取] 搭档信息: ${partner.name}, Lv.${partner.level}, 头像: ${partner.iconUrl}');
        partners.add(partner);
      } else {
        print('[搭档获取] 警告: 第 $i 个搭档数据解析失败');
      }

      // 4. 关闭弹窗
      await controller.evaluateJavascript(source: '''
        (function() {
          const closeBtn = document.querySelector('.modal-container .close');
          if (closeBtn) {
            console.log('[弹窗] 正在关闭弹窗');
            closeBtn.click();
            return true;
          }
          console.log('[弹窗] 未找到关闭按钮');
          return false;
        })();
      ''');
      print('[搭档获取] 已关闭第 $i 个搭档的弹窗');

      // 5. 等待弹窗消失
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return partners;
  }

  /// 清理资源
  void dispose() {
    _isFetching = false;
    _headlessWebView?.dispose();
    _headlessWebView = null;
    _partnerStreamController.close();
    _errorStreamController.close();
    _progressStreamController.close();
  }
}
