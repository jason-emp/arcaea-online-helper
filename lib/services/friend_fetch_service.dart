import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/friend_data.dart';
import 'friend_storage_service.dart';

/// 好友拉取服务
class FriendFetchService {
  HeadlessInAppWebView? _headlessWebView;
  final _friendStreamController =
      StreamController<List<FriendData>>.broadcast();
  final _errorStreamController = StreamController<String>.broadcast();
  final _progressStreamController = StreamController<double>.broadcast();
  final _storageService = FriendStorageService();

  Stream<List<FriendData>> get friendStream => _friendStreamController.stream;
  Stream<String> get errorStream => _errorStreamController.stream;
  Stream<double> get progressStream => _progressStreamController.stream;

  bool _isFetching = false;
  List<FriendData> _allFriends = [];

  /// 初始化WebView
  Future<InAppWebViewController> _initializeWebView() async {
    final completer = Completer<InAppWebViewController>();
    const url = 'https://arcaea.lowiro.com/zh/profile/friends';

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
        print('[好友获取] 页面开始加载: $url');
      },
      onLoadStop: (controller, url) async {
        print('[好友获取] 页面加载完成: $url');
        if (!completer.isCompleted) {
          completer.complete(controller);
        }
      },
      onLoadError: (controller, url, code, message) {
        print('[好友获取] 页面加载错误: $message');
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

  /// 开始拉取好友
  Future<void> startFetching() async {
    if (_isFetching) {
      _errorStreamController.add('正在拉取中,请稍候');
      return;
    }

    _isFetching = true;
    _allFriends = [];

    try {
      print('[好友获取] 开始初始化 WebView...');
      final controller = await _initializeWebView();
      print('[好友获取] WebView 初始化完成');

      // 等待初始页面完全加载
      await _waitForPageLoad(controller);
      print('[好友获取] 初始页面加载完成');

      // 获取好友列表
      _progressStreamController.add(0.3);
      final friends = await _fetchFriends(controller);
      
      _allFriends = friends;
      _friendStreamController.add(_allFriends);
      
      // 保存到本地存储
      await _storageService.saveFriends(_allFriends);
      
      _progressStreamController.add(1.0);
      print('[好友获取] 完成！共获取 ${_allFriends.length} 个好友');
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

  /// 从缓存加载好友数据
  Future<List<FriendData>> loadCachedFriends() async {
    try {
      final friends = await _storageService.loadFriends();
      if (friends.isNotEmpty) {
        _allFriends = friends;
        _friendStreamController.add(_allFriends);
      }
      return friends;
    } catch (e) {
      print('[好友获取] 加载缓存失败: $e');
      return [];
    }
  }

  /// 获取最后更新时间
  Future<DateTime?> getLastUpdateTime() async {
    return await _storageService.getLastUpdateTime();
  }

  /// 清除好友数据
  Future<void> clearFriendData() async {
    await _storageService.clearFriends();
    _allFriends = [];
    _friendStreamController.add([]);
  }

  Future<void> _waitForPageLoad(InAppWebViewController controller) async {
    print('[好友获取] 开始等待页面内容加载...');
    
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
            const cards = list ? list.querySelectorAll('.cardfriend') : [];
            console.log('[页面检查] .list: ' + (list !== null) + ', cards: ' + cards.length);
            return list !== null && cards.length > 0;
          })();
        ''');
        if (result == true) {
          print('[好友获取] 页面加载完成，找到 .list 元素和好友卡片');
          // iOS 平台增加更长的渲染等待时间
          final renderDelay = Platform.isIOS 
              ? const Duration(milliseconds: 1200) 
              : const Duration(milliseconds: 800);
          await Future.delayed(renderDelay);
          return;
        }
      } catch (e) {
        print('[好友获取] 页面检查异常: $e');
        if (Platform.isIOS) {
          // iOS 上如果出现异常，可能是 WebView 被释放了
          break;
        }
      }
    }
    print('[好友获取] 警告: 页面加载超时，未找到完整内容');
  }

  Future<List<FriendData>> _fetchFriends(
      InAppWebViewController controller) async {
    List<FriendData> friends = [];

    try {
      print('[好友获取] 开始解析好友列表...');
      
      // 使用JavaScript获取所有好友数据
      final result = await controller.evaluateJavascript(source: '''
        (function() {
          const friendCards = document.querySelectorAll('.cardfriend');
          const friendsData = [];
          
          friendCards.forEach((card, index) => {
            try {
              // 获取时间文本
              const timeElement = card.querySelector('.numtext');
              const lastActiveTime = timeElement ? timeElement.textContent.trim() : '';
              
              // 检查是否为互相好友
              const mutualImg = card.querySelector('img.mutual');
              const isMutual = mutualImg !== null;
              
              // 获取内容区域
              const content = card.querySelector('.content');
              if (!content) {
                console.log('[好友解析] 索引 ' + index + ' 没有 content 元素');
                return;
              }
              
              // 获取用户名
              const usernameElement = content.querySelector('.username');
              const username = usernameElement ? usernameElement.textContent.trim() : '';
              
              // 获取歌曲名
              const subheadElement = content.querySelector('.subhead p');
              const songName = subheadElement ? subheadElement.textContent.trim() : '';
              
              // 获取角色图像
              const profileImage = content.querySelector('.profile-image');
              if (!profileImage) {
                console.log('[好友解析] 索引 ' + index + ' 没有 profile-image');
                return;
              }
              
              const bgStyle = profileImage.style.backgroundImage || '';
              const characterIconUrl = bgStyle.match(/url\\(["']?([^"']*)["']?\\)/)?.[1] || '';
              
              // 获取评分信息
              const diamond = profileImage.querySelector('.diamond');
              if (!diamond) {
                console.log('[好友解析] 索引 ' + index + ' 没有 diamond 评分');
                return;
              }
              
              // 获取评分等级类名
              let ratingClass = '';
              for (let cls of diamond.classList) {
                if (cls.startsWith('rating_')) {
                  ratingClass = cls;
                  break;
                }
              }
              
              // 获取评分图片
              const ratingBgStyle = diamond.style.backgroundImage || '';
              const ratingImageUrl = ratingBgStyle.match(/url\\(["']?([^"']*)["']?\\)/)?.[1] || '';
              
              // 获取评分数值
              const decimalElement = diamond.querySelector('.decimal');
              const fixedElement = diamond.querySelector('.fixed');
              let decimalText = decimalElement ? decimalElement.textContent.trim() : '0';
              const fixedText = fixedElement ? fixedElement.textContent.trim() : '00';
              
              // 移除 decimal 中可能存在的小数点
              decimalText = decimalText.replace('.', '');
              
              const ratingValue = parseFloat(decimalText + '.' + fixedText);
              
              friendsData.push({
                username: username,
                lastActiveTime: lastActiveTime,
                songName: songName,
                characterIconUrl: characterIconUrl,
                ratingClass: ratingClass,
                ratingImageUrl: ratingImageUrl,
                ratingValue: ratingValue,
                isMutual: isMutual
              });
              
              console.log('[好友解析] 成功解析好友 ' + index + ': ' + username);
            } catch (e) {
              console.log('[好友解析] 解析索引 ' + index + ' 失败: ' + e.message);
            }
          });
          
          return JSON.stringify(friendsData);
        })();
      ''');

      if (result != null) {
        final List<dynamic> jsonList = jsonDecode(result.toString());
        friends = jsonList.map((json) => FriendData.fromJson(json)).toList();
        print('[好友获取] 成功解析 ${friends.length} 个好友');
      }
    } catch (e) {
      print('[好友获取] 解析好友数据失败: $e');
      _errorStreamController.add('解析好友数据失败: $e');
    }

    return friends;
  }

  void dispose() {
    _friendStreamController.close();
    _errorStreamController.close();
    _progressStreamController.close();
  }
}
