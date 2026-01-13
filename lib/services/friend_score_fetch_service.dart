import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/friend_score_data.dart';
import 'friend_score_storage_service.dart';

/// 页面范围拉取任务
class _PageRangeFetchTask {
  final HeadlessInAppWebView webView;
  final String difficulty;
  final int difficultyIndex;
  final int startPage;
  final int endPage; // -1 表示无限制
  final String taskId;
  bool encounteredEmptyPage = false;

  _PageRangeFetchTask({
    required this.webView,
    required this.difficulty,
    required this.difficultyIndex,
    required this.startPage,
    required this.endPage,
    required this.taskId,
  });
}

/// 好友成绩拉取服务
/// 使用多个WebView并行从官网拉取好友成绩数据
/// FTR难度使用多线程分页并行拉取，其他难度单线程
class FriendScoreFetchService {
  final List<HeadlessInAppWebView> _webViews = [];
  final _friendScoreStreamController =
      StreamController<FriendScoreListResponse>.broadcast();
  final _errorStreamController = StreamController<String>.broadcast();
  final _progressStreamController = StreamController<double>.broadcast();
  final _difficultyStreamController = StreamController<String>.broadcast();
  final _taskProgressStreamController = StreamController<Map<String, double>>.broadcast();
  final _storageService = FriendScoreStorageService();

  Stream<FriendScoreListResponse> get friendScoreStream =>
      _friendScoreStreamController.stream;
  Stream<String> get errorStream => _errorStreamController.stream;
  Stream<double> get progressStream => _progressStreamController.stream;
  Stream<String> get difficultyStream => _difficultyStreamController.stream;
  Stream<Map<String, double>> get taskProgressStream => _taskProgressStreamController.stream;

  bool _isFetching = false;
  List<SongFriendScores> _allSongs = [];
  final List<String> _difficulties = ['PST', 'PRS', 'FTR', 'ETR', 'BYD'];
  
  // FTR 分页并行配置
  static const int _ftrPagesPerThread = 5;  // 每个线程处理5页
  static const int _ftrMaxThreads = 6;       // FTR最多6个线程（覆盖30页）
  
  // 并行进度追踪
  final Map<String, double> _taskProgress = {};
  int _totalTasks = 0;
  
  // FTR 空页检测（用于提前终止后续线程）
  int _ftrFirstEmptyPageFound = -1;

  /// 加载缓存的好友成绩
  Future<List<SongFriendScores>> loadCachedFriendScores() async {
    return await _storageService.loadFriendScores();
  }

  /// 初始化单个WebView，直接导航到指定页面
  Future<_PageRangeFetchTask> _initializeWebViewForPageRange(
    String difficulty,
    int difficultyIndex,
    int startPage,
    int endPage,
    String taskId,
  ) async {
    final completer = Completer<InAppWebViewController>();
    final url = 'https://arcaea.lowiro.com/zh/profile/scores?page=$startPage';

    final webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      ),
      onLoadStop: (controller, url) async {
        if (!completer.isCompleted) {
          completer.complete(controller);
        }
      },
      onLoadError: (controller, url, code, message) {
        if (!completer.isCompleted) {
          completer.completeError('页面加载失败: $message');
        }
      },
    );

    _webViews.add(webView);
    await webView.run();
    
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('初始化 WebView 超时，请检查网络连接');
      },
    );

    return _PageRangeFetchTask(
      webView: webView,
      difficulty: difficulty,
      difficultyIndex: difficultyIndex,
      startPage: startPage,
      endPage: endPage,
      taskId: taskId,
    );
  }

  /// 清理所有 WebView
  Future<void> _cleanupAllWebViews() async {
    for (final webView in _webViews) {
      await webView.dispose();
    }
    _webViews.clear();
  }

  /// 开始并行拉取好友成绩
  Future<void> startFetching() async {
    if (_isFetching) {
      _errorStreamController.add('正在拉取中,请稍候');
      return;
    }

    _isFetching = true;
    _allSongs = [];
    _taskProgress.clear();
    _ftrFirstEmptyPageFound = -1;

    try {
      // 构建所有任务
      final taskConfigs = <Map<String, dynamic>>[];
      
      // 非FTR难度：每个难度一个任务
      for (int i = 0; i < _difficulties.length; i++) {
        final diff = _difficulties[i];
        if (diff != 'FTR') {
          taskConfigs.add({
            'difficulty': diff,
            'difficultyIndex': i,
            'startPage': 1,
            'endPage': -1,  // 无限制，拉取到空页为止
            'taskId': diff,
          });
        }
      }
      
      // FTR难度：分成多个任务，每个任务处理5页，最后一个线程无上限
      final ftrIndex = _difficulties.indexOf('FTR');
      for (int t = 0; t < _ftrMaxThreads; t++) {
        final startPage = t * _ftrPagesPerThread + 1;
        // 最后一个线程不设上限，继续拉取直到遇到空页
        final endPage = (t == _ftrMaxThreads - 1) ? -1 : (t + 1) * _ftrPagesPerThread;
        final taskIdSuffix = endPage == -1 ? '$startPage+' : '$startPage-$endPage';
        taskConfigs.add({
          'difficulty': 'FTR',
          'difficultyIndex': ftrIndex,
          'startPage': startPage,
          'endPage': endPage,
          'taskId': 'FTR_$taskIdSuffix',
        });
      }
      
      _totalTasks = taskConfigs.length;
      
      // 初始化进度
      for (final config in taskConfigs) {
        _taskProgress[config['taskId']] = 0.0;
      }

      // 发送初始状态
      final ftrThreadCount = _ftrMaxThreads;
      final otherDiffs = _difficulties.where((d) => d != 'FTR').join(', ');
      _difficultyStreamController.add(
        '并行拉取: FTR($ftrThreadCount线程) + $otherDiffs'
      );

      // 并行初始化所有 WebView
      final taskFutures = <Future<_PageRangeFetchTask>>[];
      for (final config in taskConfigs) {
        taskFutures.add(_initializeWebViewForPageRange(
          config['difficulty'],
          config['difficultyIndex'],
          config['startPage'],
          config['endPage'],
          config['taskId'],
        ));
      }
      
      final tasks = await Future.wait(taskFutures);

      // 并行拉取所有任务
      final fetchFutures = tasks.map((task) => _fetchPageRangeFriendScores(task));
      await Future.wait(fetchFutures);

      // _allSongs 已经在 _updateStreamWithAllData 中实时更新了

      // 保存到本地存储
      if (_allSongs.isNotEmpty) {
        await _storageService.saveFriendScores(_allSongs);
      }

      _isFetching = false;
      _progressStreamController.add(-1); // 完成标记
    } catch (e) {
      _isFetching = false;
      _errorStreamController.add('拉取错误: $e');
      _progressStreamController.add(-1);
    } finally {
      await _cleanupAllWebViews();
    }
  }

  /// 停止拉取
  void stopFetching() {
    _isFetching = false;
  }

  /// 更新总体进度
  void _updateOverallProgress() {
    if (_taskProgress.isEmpty || _totalTasks == 0) return;
    
    double total = 0;
    for (final progress in _taskProgress.values) {
      total += progress;
    }
    final overallProgress = total / _totalTasks;
    _progressStreamController.add(overallProgress);
    
    // 同时发送各任务进度
    _taskProgressStreamController.add(Map.from(_taskProgress));
  }

  /// 拉取指定页面范围的好友成绩
  Future<List<SongFriendScores>> _fetchPageRangeFriendScores(
    _PageRangeFetchTask task,
  ) async {
    final controller = await task.webView.webViewController;
    if (controller == null) return [];

    final difficulty = task.difficulty;
    final difficultyIndex = task.difficultyIndex;
    final startPage = task.startPage;
    final endPage = task.endPage;
    final taskId = task.taskId;
    
    // FTR使用URL翻页，其他难度使用点击翻页
    if (difficulty == 'FTR') {
      return _fetchFtrPagesWithUrl(controller, difficultyIndex, startPage, endPage, taskId);
    } else {
      return _fetchNonFtrPagesWithClick(controller, difficulty, difficultyIndex, taskId);
    }
  }

  /// FTR专用：使用URL直接跳转翻页
  Future<List<SongFriendScores>> _fetchFtrPagesWithUrl(
    InAppWebViewController controller,
    int difficultyIndex,
    int startPage,
    int endPage,
    String taskId,
  ) async {
    var allSongs = <SongFriendScores>[];
    final processedSongKeys = <String>{};
    const difficulty = 'FTR';

    try {
      // 等待DOM元素出现
      bool domReady = false;
      for (int i = 0; i < 15; i++) {
        final checkDom = await controller.evaluateJavascript(
          source: '''
          (function() {
            const diffSelectors = document.querySelectorAll('.difficulty-selector');
            return diffSelectors.length > 0;
          })();
        ''',
        );

        if (checkDom == true) {
          domReady = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (!domReady) {
        _taskProgress[taskId] = 1.0;
        _updateOverallProgress();
        return [];
      }

      // FTR是默认难度（index=2），通常已激活，只需确认
      final clickScript = '''
        (function() {
          const diffSelectors = document.querySelectorAll('.difficulty-selector');
          if ($difficultyIndex < diffSelectors.length) {
            if (diffSelectors[$difficultyIndex].classList.contains('active')) {
              return 'already_active';
            }
            diffSelectors[$difficultyIndex].click();
            return true;
          }
          return false;
        })();
      ''';

      final clickResult = await controller.evaluateJavascript(source: clickScript);
      if (clickResult != 'already_active') {
        await Future.delayed(const Duration(milliseconds: 800));
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 等待卡片加载
      for (int i = 0; i < 10; i++) {
        final checkCards = await controller.evaluateJavascript(
          source: '''
          (function() {
            return document.querySelectorAll('.list-card .card-container').length > 0;
          })();
        ''',
        );
        if (checkCards == true) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 开始拉取页面
      int currentPage = startPage;
      final maxPage = endPage > 0 ? endPage : 999;
      int consecutiveEmptyPages = 0;

      while (currentPage <= maxPage && _isFetching) {
        // 检查是否有其他FTR线程发现空页
        if (_ftrFirstEmptyPageFound > 0 && currentPage >= _ftrFirstEmptyPageFound) {
          break;
        }

        // 更新进度
        if (endPage > 0) {
          final pagesInRange = endPage - startPage + 1;
          final pagesDone = currentPage - startPage;
          _taskProgress[taskId] = (pagesDone / pagesInRange).clamp(0.0, 0.95);
        } else {
          _taskProgress[taskId] = ((currentPage - startPage) / 20.0).clamp(0.0, 0.95);
        }
        _updateOverallProgress();

        // 获取当前页面歌曲
        final songs = await _fetchCurrentPageFriendScores(
          controller,
          difficulty,
          processedSongKeys,
        );

        if (songs.isEmpty) {
          consecutiveEmptyPages++;
          if (_ftrFirstEmptyPageFound < 0) {
            _ftrFirstEmptyPageFound = currentPage;
          }
          if (consecutiveEmptyPages >= 2) {
            break;
          }
        } else {
          consecutiveEmptyPages = 0;
          allSongs.addAll(songs);
          _updateStreamWithAllData(songs, difficulty, currentPage);
        }

        // 移动到下一页（FTR用URL翻页）
        currentPage++;
        if (currentPage <= maxPage && _isFetching && consecutiveEmptyPages == 0) {
          final nextUrl = 'https://arcaea.lowiro.com/zh/profile/scores?page=$currentPage';
          await controller.loadUrl(urlRequest: URLRequest(url: WebUri(nextUrl)));
          
          // 等待页面加载
          await Future.delayed(const Duration(milliseconds: 1000));
          
          // 等待卡片加载
          for (int i = 0; i < 15; i++) {
            final checkCards = await controller.evaluateJavascript(
              source: '''
              (function() {
                return document.querySelectorAll('.list-card .card-container').length > 0;
              })();
            ''',
            );
            if (checkCards == true) break;
            await Future.delayed(const Duration(milliseconds: 200));
          }
          
          // FTR是默认难度，URL翻页后无需切换
        }
      }

      _taskProgress[taskId] = 1.0;
      _updateOverallProgress();
      return allSongs;
    } catch (e) {
      _taskProgress[taskId] = 1.0;
      _updateOverallProgress();
      return allSongs;
    }
  }

  /// 非FTR难度：使用点击翻页按钮
  Future<List<SongFriendScores>> _fetchNonFtrPagesWithClick(
    InAppWebViewController controller,
    String difficulty,
    int difficultyIndex,
    String taskId,
  ) async {
    var allSongs = <SongFriendScores>[];
    final processedSongKeys = <String>{};

    try {
      // 等待DOM元素出现
      bool domReady = false;
      for (int i = 0; i < 15; i++) {
        final checkDom = await controller.evaluateJavascript(
          source: '''
          (function() {
            const diffSelectors = document.querySelectorAll('.difficulty-selector');
            return diffSelectors.length > 0;
          })();
        ''',
        );

        if (checkDom == true) {
          domReady = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (!domReady) {
        _taskProgress[taskId] = 1.0;
        _updateOverallProgress();
        return [];
      }

      // 切换到目标难度
      final clickScript = '''
        (function() {
          const diffSelectors = document.querySelectorAll('.difficulty-selector');
          if ($difficultyIndex < diffSelectors.length) {
            if (diffSelectors[$difficultyIndex].classList.contains('active')) {
              return 'already_active';
            }
            diffSelectors[$difficultyIndex].click();
            return true;
          }
          return false;
        })();
      ''';

      final clickResult = await controller.evaluateJavascript(source: clickScript);
      if (clickResult == false) {
        _taskProgress[taskId] = 1.0;
        _updateOverallProgress();
        return [];
      }

      // 切换难度后等待页面刷新
      await Future.delayed(const Duration(milliseconds: 1000));

      // 等待卡片加载
      for (int i = 0; i < 15; i++) {
        final checkCards = await controller.evaluateJavascript(
          source: '''
          (function() {
            return document.querySelectorAll('.list-card .card-container').length > 0;
          })();
        ''',
        );
        if (checkCards == true) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 开始拉取页面（使用点击翻页）
      int currentPage = 1;
      bool hasMore = true;
      int consecutiveEmptyPages = 0;

      while (hasMore && _isFetching) {
        // 更新进度
        _taskProgress[taskId] = (currentPage / 20.0).clamp(0.0, 0.95);
        _updateOverallProgress();

        // 记录当前页面第一首歌的标题（用于检测翻页是否成功）
        final firstSongTitle = await _getFirstSongTitle(controller);

        // 获取当前页面歌曲
        final songs = await _fetchCurrentPageFriendScores(
          controller,
          difficulty,
          processedSongKeys,
        );

        if (songs.isEmpty) {
          consecutiveEmptyPages++;
          if (consecutiveEmptyPages >= 2) {
            hasMore = false;
            break;
          }
        } else {
          consecutiveEmptyPages = 0;
          allSongs.addAll(songs);
          _updateStreamWithAllData(songs, difficulty, currentPage);
        }

        // 检查是否有下一页
        final hasNextPage = await _hasNextPage(controller);
        if (!hasNextPage) {
          hasMore = false;
          break;
        }

        // 点击下一页按钮
        final clickedNext = await _clickNextPageButton(controller);
        if (!clickedNext) {
          hasMore = false;
          break;
        }

        // 等待页面更新
        bool pageChanged = false;
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          final newFirstSongTitle = await _getFirstSongTitle(controller);
          if (newFirstSongTitle != firstSongTitle && newFirstSongTitle.isNotEmpty) {
            pageChanged = true;
            break;
          }
        }

        if (!pageChanged) {
          hasMore = false;
        } else {
          currentPage++;
        }
      }

      _taskProgress[taskId] = 1.0;
      _updateOverallProgress();
      return allSongs;
    } catch (e) {
      _taskProgress[taskId] = 1.0;
      _updateOverallProgress();
      return allSongs;
    }
  }

  /// 获取当前页面第一首歌的标题
  Future<String> _getFirstSongTitle(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function() {
          const firstCard = document.querySelector('.list-card .card-container .card');
          if (firstCard) {
            const titleElement = firstCard.querySelector('.title .no-overflow');
            return titleElement ? titleElement.textContent.trim() : '';
          }
          return '';
        })();
      ''',
      );
      return result?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  /// 检查是否有下一页
  Future<bool> _hasNextPage(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function() {
          const pageButtons = document.querySelectorAll('span.no-select');
          for (let i = 0; i < pageButtons.length; i++) {
            const button = pageButtons[i];
            const img = button.querySelector('img');
            if (img && img.src && img.src.includes('Path_1121')) {
              if (img.src.includes("rotate(-90)")) {
                const parent = button.parentElement;
                const isDisabled = button.classList.contains('disabled') || 
                                 (parent && parent.classList.contains('disabled'));
                if (!isDisabled) {
                  return true;
                }
              }
            }
          }
          return false;
        })();
      ''',
      );
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// 点击下一页按钮
  Future<bool> _clickNextPageButton(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function() {
          const pageButtons = document.querySelectorAll('span.no-select');
          for (let i = 0; i < pageButtons.length; i++) {
            const button = pageButtons[i];
            const img = button.querySelector('img');
            if (img && img.src && img.src.includes('Path_1121')) {
              if (img.src.includes("rotate(-90)")) {
                const parent = button.parentElement;
                if (!parent || !parent.classList.contains('disabled')) {
                  button.click();
                  return true;
                }
              }
            }
          }
          return false;
        })();
      ''',
      );
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// 更新Stream，合并当前所有已拉取的数据
  void _updateStreamWithAllData(
    List<SongFriendScores> newSongs,
    String currentDifficulty,
    int currentPage,
  ) {
    // 合并到 _allSongs（需要去重）
    for (final song in newSongs) {
      final existingIndex = _allSongs.indexWhere(
        (s) => s.songTitle == song.songTitle && s.difficulty == song.difficulty,
      );
      if (existingIndex == -1) {
        _allSongs.add(song);
      }
    }

    _friendScoreStreamController.add(
      FriendScoreListResponse(
        songs: List.from(_allSongs),
        currentPage: currentPage,
        hasNextPage: true,
        currentDifficulty: currentDifficulty,
      ),
    );
  }

  /// 获取当前页面所有歌曲的好友成绩
  Future<List<SongFriendScores>> _fetchCurrentPageFriendScores(
    InAppWebViewController controller,
    String difficulty,
    Set<String> processedSongKeys,
  ) async {
    final songs = <SongFriendScores>[];

    try {
      // 获取当前页面的所有歌曲卡片数量
      final cardCountResult = await controller.evaluateJavascript(
        source: '''
          (function() {
            return document.querySelectorAll('.list-card .card-container').length;
          })();
        ''',
      );

      final cardCount = cardCountResult as int? ?? 0;
      if (cardCount == 0) return songs;

      // 遍历每个歌曲卡片
      for (int cardIndex = 0; cardIndex < cardCount; cardIndex++) {
        if (!_isFetching) break;

        // 获取歌曲基本信息
        final songInfoResult = await controller.evaluateJavascript(
          source: _getSongInfoScript(cardIndex),
        );

        if (songInfoResult == null) continue;

        Map<String, dynamic> songInfo;
        if (songInfoResult is String) {
          songInfo = jsonDecode(songInfoResult);
        } else {
          songInfo = Map<String, dynamic>.from(songInfoResult);
        }

        if (songInfo['songTitle'] == null || songInfo['songTitle'].isEmpty) {
          continue;
        }

        // 生成歌曲唯一键用于去重
        final songKey = '${songInfo['songTitle']}_$difficulty';
        if (processedSongKeys.contains(songKey)) {
          // 已处理过该歌曲，跳过
          continue;
        }

        // 点击箭头展开下拉菜单
        final expandResult = await controller.evaluateJavascript(
          source: _getExpandCardScript(cardIndex),
        );

        if (expandResult != true) continue;

        // 等待下拉菜单展开
        await Future.delayed(const Duration(milliseconds: 300));

        // 点击排行榜按钮
        final clickRankResult = await controller.evaluateJavascript(
          source: _getClickRankButtonScript(cardIndex),
        );

        if (clickRankResult != true) {
          // 关闭下拉菜单
          await controller.evaluateJavascript(
            source: _getCollapseCardScript(cardIndex),
          );
          continue;
        }

        // 等待弹窗出现
        await Future.delayed(const Duration(milliseconds: 400));

        // 检查弹窗是否出现
        final modalReady = await _waitForModal(controller);
        if (!modalReady) {
          await _closeModal(controller);
          continue;
        }

        // 点击"好友"按钮切换到好友排行榜
        final clickFriendResult = await controller.evaluateJavascript(
          source: _getClickFriendButtonScript(),
        );

        if (clickFriendResult == true) {
          // 等待好友排行榜加载
          await Future.delayed(const Duration(milliseconds: 400));
        }

        // 获取好友成绩
        final friendScoresResult = await controller.evaluateJavascript(
          source: _getParseFriendScoresScript(),
        );

        if (friendScoresResult != null) {
          List<dynamic> friendScoresJson;
          if (friendScoresResult is String) {
            friendScoresJson = jsonDecode(friendScoresResult);
          } else {
            friendScoresJson = List<dynamic>.from(friendScoresResult);
          }

          if (friendScoresJson.isNotEmpty) {
            final friendScores = friendScoresJson
                .map((e) => FriendScoreData.fromJson({
                      ...Map<String, dynamic>.from(e),
                      'songTitle': songInfo['songTitle'],
                      'artist': songInfo['artist'],
                      'albumArtUrl': songInfo['albumArtUrl'],
                      'difficulty': difficulty,
                    }))
                .toList();

            songs.add(SongFriendScores(
              songTitle: songInfo['songTitle'] as String,
              artist: songInfo['artist'] as String,
              albumArtUrl: songInfo['albumArtUrl'] as String,
              difficulty: difficulty,
              friendScores: friendScores,
            ));

            // 标记该歌曲已处理
            processedSongKeys.add(songKey);
          }
        }

        // 关闭弹窗
        await _closeModal(controller);

        // 小延迟以避免过快操作
        await Future.delayed(const Duration(milliseconds: 150));
      }

      return songs;
    } catch (e) {
      return songs;
    }
  }

  /// 等待弹窗出现
  Future<bool> _waitForModal(InAppWebViewController controller) async {
    for (int i = 0; i < 15; i++) {
      final result = await controller.evaluateJavascript(
        source: '''
          (function() {
            return document.querySelector('.modal-container') !== null;
          })();
        ''',
      );
      if (result == true) return true;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return false;
  }

  /// 关闭弹窗
  Future<void> _closeModal(InAppWebViewController controller) async {
    await controller.evaluateJavascript(
      source: '''
        (function() {
          const closeBtn = document.querySelector('.modal-container .close');
          if (closeBtn) {
            closeBtn.click();
            return true;
          }
          return false;
        })();
      ''',
    );
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// 获取歌曲基本信息的脚本
  String _getSongInfoScript(int cardIndex) {
    return '''
(function() {
  const cards = document.querySelectorAll('.list-card .card-container');
  if ($cardIndex >= cards.length) return null;
  
  const container = cards[$cardIndex];
  const card = container.querySelector('.card');
  if (!card) return null;
  
  const titleElement = card.querySelector('.title .no-overflow');
  const songTitle = titleElement ? titleElement.textContent.trim() : '';
  
  const artistElements = card.querySelectorAll('.header-ta');
  let artist = '';
  if (artistElements.length >= 2) {
    const artistSpan = artistElements[1].querySelector('.no-overflow');
    artist = artistSpan ? artistSpan.textContent.trim() : '';
  }
  
  const albumElement = card.querySelector('.album-jacket');
  const albumArtUrl = albumElement ? albumElement.src : '';
  
  return JSON.stringify({
    songTitle: songTitle,
    artist: artist,
    albumArtUrl: albumArtUrl
  });
})();
''';
  }

  /// 展开卡片的脚本
  String _getExpandCardScript(int cardIndex) {
    return '''
(function() {
  const cards = document.querySelectorAll('.list-card .card-container');
  if ($cardIndex >= cards.length) return false;
  
  const container = cards[$cardIndex];
  const arrow = container.querySelector('.no-active');
  if (arrow) {
    arrow.click();
    return true;
  }
  return false;
})();
''';
  }

  /// 收起卡片的脚本
  String _getCollapseCardScript(int cardIndex) {
    return '''
(function() {
  const cards = document.querySelectorAll('.list-card .card-container');
  if ($cardIndex >= cards.length) return false;
  
  const container = cards[$cardIndex];
  const active = container.querySelector('.active .up-arrow-container');
  if (active) {
    active.click();
    return true;
  }
  return false;
})();
''';
  }

  /// 点击排行榜按钮的脚本
  String _getClickRankButtonScript(int cardIndex) {
    return '''
(function() {
  const cards = document.querySelectorAll('.list-card .card-container');
  if ($cardIndex >= cards.length) return false;
  
  const container = cards[$cardIndex];
  const active = container.querySelector('.active');
  if (!active) return false;
  
  // 查找排行榜按钮（button-static class）
  const rankButton = active.querySelector('.button-static');
  if (rankButton) {
    rankButton.click();
    return true;
  }
  return false;
})();
''';
  }

  /// 点击"好友"按钮的脚本
  String _getClickFriendButtonScript() {
    return '''
(function() {
  const modal = document.querySelector('.modal-container');
  if (!modal) return false;
  
  // 查找"好友"按钮（在button-modal中的第二个btn-hexagon）
  const buttons = modal.querySelectorAll('.button-modal .btn-hexagon');
  for (let i = 0; i < buttons.length; i++) {
    const text = buttons[i].querySelector('.text');
    if (text && text.textContent.trim() === '好友') {
      buttons[i].click();
      return true;
    }
  }
  return false;
})();
''';
  }

  /// 解析好友成绩的脚本
  String _getParseFriendScoresScript() {
    return '''
(function() {
  const modal = document.querySelector('.modal-container');
  if (!modal) return null;
  
  const scoreCards = modal.querySelectorAll('.card-score-data-modal');
  const scores = [];
  
  scoreCards.forEach((card, index) => {
    try {
      const rankElement = card.querySelector('.rank-number p');
      const rank = rankElement ? parseInt(rankElement.textContent.replace('#', '')) : index + 1;
      
      const usernameElement = card.querySelector('.username');
      const username = usernameElement ? usernameElement.textContent.trim() : '';
      
      const scoreElement = card.querySelector('.score');
      let score = 0;
      if (scoreElement) {
        const scoreText = scoreElement.textContent.trim().replace(/,/g, '');
        score = parseInt(scoreText) || 0;
      }
      
      const gradeElement = card.querySelector('.ex-main span');
      const grade = gradeElement ? gradeElement.textContent.trim() : '';
      
      const characterImg = card.querySelector('.diamond img');
      const characterIconUrl = characterImg ? characterImg.src : '';
      
      if (username) {
        scores.push({
          username: username,
          score: score,
          grade: grade,
          characterIconUrl: characterIconUrl,
          rank: rank
        });
      }
    } catch (e) {
      console.error('解析好友成绩错误:', e);
    }
  });
  
  return JSON.stringify(scores);
})();
''';
  }

  /// 清除好友成绩数据
  Future<void> clearFriendScoreData() async {
    await _storageService.clearCache();
  }

  /// 清理资源
  void dispose() {
    _isFetching = false;
    _cleanupAllWebViews();
    _friendScoreStreamController.close();
    _errorStreamController.close();
    _progressStreamController.close();
    _difficultyStreamController.close();
    _taskProgressStreamController.close();
  }
}
