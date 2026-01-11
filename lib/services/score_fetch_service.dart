import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/score_data.dart';
import 'score_storage_service.dart';
import 'song_data_service.dart';

/// 成绩拉取服务
/// 使用WebView从官网拉取成绩数据
class ScoreFetchService {
  HeadlessInAppWebView? _headlessWebView;
  final _scoreStreamController =
      StreamController<ScoreListResponse>.broadcast();
  final _errorStreamController = StreamController<String>.broadcast();
  final _progressStreamController = StreamController<double>.broadcast();
  final _difficultyStreamController = StreamController<String>.broadcast();
  final _storageService = ScoreStorageService();
  final _songDataService = SongDataService();

  Stream<ScoreListResponse> get scoreStream => _scoreStreamController.stream;
  Stream<String> get errorStream => _errorStreamController.stream;
  Stream<double> get progressStream => _progressStreamController.stream;
  Stream<String> get difficultyStream => _difficultyStreamController.stream;

  bool _isFetching = false;
  List<ScoreData> _allScores = [];
  final List<String> _difficulties = ['PST', 'PRS', 'FTR', 'ETR', 'BYD'];
  bool _isUpdateMode = false;
  Set<String> _existingDates = {};
  double? _latestPlayerPTT;

  /// 初始化WebView
  Future<InAppWebViewController> _initializeWebView() async {
    final completer = Completer<InAppWebViewController>();
    const url = 'https://arcaea.lowiro.com/zh/profile/scores?page=1';

    _headlessWebView = HeadlessInAppWebView(
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

    await _headlessWebView!.run();
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('初始化 WebView 超时，请检查网络连接');
      },
    );
  }

  /// 清理 WebView
  Future<void> _cleanupWebView() async {
    if (_headlessWebView != null) {
      await _headlessWebView!.dispose();
      _headlessWebView = null;
    }
  }

  /// 开始增量更新成绩
  /// 只拉取新成绩，遇到已有日期的成绩时停止
  /// [difficulties] 要更新的难度列表，如果为null则更新所有难度
  Future<void> startUpdating({List<String>? difficulties}) async {
    if (_isFetching) {
      _errorStreamController.add('正在拉取中,请稍候');
      return;
    }

    _isFetching = true;
    _isUpdateMode = true;

    try {
      // 确保歌曲数据已加载
      await _songDataService.ensureLoaded();

      // 加载已有成绩的日期集合
      final existingScores = await _storageService.loadScores();
      _existingDates = existingScores.map((s) => s.obtainedDate).toSet();

      // 确定要更新的难度列表
      final targetDifficulties = difficulties ?? _difficulties;

      // 初始化 WebView
      final controller = await _initializeWebView();

      // 遍历选定的难度
      for (int i = 0; i < targetDifficulties.length; i++) {
        if (!_isFetching) break;

        final difficulty = targetDifficulties[i];
        final diffIndex = _difficulties.indexOf(difficulty);

        if (diffIndex == -1) {
          continue;
        }

        // 发送当前难度信息
        _difficultyStreamController.add(difficulty);

        // 拉取该难度的新成绩
        final difficultyScores = await _fetchDifficultyScores(
          controller,
          difficulty,
          diffIndex,
          i,
          targetDifficulties.length,
        );

        if (difficultyScores.isNotEmpty) {
          // 追加新成绩（使用存储服务的合并去重功能）
          await _storageService.appendScores(difficultyScores);

          // 重新加载所有成绩以更新UI
          _allScores = await _storageService.loadScores();
        }

        // 难度之间延迟（减少延迟以节约时间）
        if (i < targetDifficulties.length - 1 && _isFetching) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      _isFetching = false;
      _isUpdateMode = false;
      _existingDates.clear();
      _progressStreamController.add(-1); // 完成标记
    } catch (e) {
      _isFetching = false;
      _isUpdateMode = false;
      _existingDates.clear();
      _errorStreamController.add('更新错误: $e');
      _progressStreamController.add(-1);
    } finally {
      await _cleanupWebView();
    }
  }

  /// 开始拉取成绩
  /// 拉取所有难度的所有页面
  Future<void> startFetching() async {
    if (_isFetching) {
      _errorStreamController.add('正在拉取中,请稍候');
      return;
    }

    _isFetching = true;
    _allScores = [];

    try {
      // 确保歌曲数据已加载
      await _songDataService.ensureLoaded();

      // 初始化 WebView
      final controller = await _initializeWebView();

      // 遍历所有难度
      for (int diffIndex = 0; diffIndex < _difficulties.length; diffIndex++) {
        if (!_isFetching) break;

        final difficulty = _difficulties[diffIndex];

        // 发送当前难度信息
        _difficultyStreamController.add(difficulty);

        // 拉取该难度的所有页面
        final difficultyScores = await _fetchDifficultyScores(
          controller,
          difficulty,
          diffIndex,
          diffIndex,
          _difficulties.length,
        );

        if (difficultyScores.isNotEmpty) {
          // 添加前先去重（防止与已有成绩重复）
          _allScores.addAll(difficultyScores);
          _allScores = _deduplicateScores(_allScores);

          // 保存到本地存储
          await _storageService.saveScores(_allScores);
        }

        // 难度之间延迟（减少延迟以节约时间）
        if (diffIndex < _difficulties.length - 1 && _isFetching) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // 最终去重并保存
      _allScores = _deduplicateScores(_allScores);
      await _storageService.saveScores(_allScores);

      _isFetching = false;
      _progressStreamController.add(-1); // 完成标记
    } catch (e) {
      _isFetching = false;
      _errorStreamController.add('拉取错误: $e');
      _progressStreamController.add(-1);
    } finally {
      await _cleanupWebView();
    }
  }

  /// 停止拉取
  void stopFetching() {
    _isFetching = false;
  }

  /// 成绩去重
  /// 去重规则：相同歌曲标题 + 相同难度，只保留分数最高的
  List<ScoreData> _deduplicateScores(List<ScoreData> scores) {
    final Map<String, ScoreData> scoreMap = {};

    for (var score in scores) {
      // 生成唯一键：歌曲标题_难度
      final key = '${score.songTitle}_${score.difficulty}';

      // 如果key已存在，比较分数，保留分数更高的
      if (scoreMap.containsKey(key)) {
        final existing = scoreMap[key]!;
        if (score.score > existing.score) {
          // 新成绩分数更高，替换旧成绩
          scoreMap[key] = score;
        }
        // 否则保留现有的（分数更高或相等）
      } else {
        // 首次遇到该曲目+难度，直接添加
        scoreMap[key] = score;
      }
    }

    return scoreMap.values.toList();
  }

  /// 从URL中提取page参数的值
  int? _extractPageNumber(String? url) {
    if (url == null || url.isEmpty) return null;

    try {
      final uri = Uri.parse(url);
      final pageParam = uri.queryParameters['page'];
      if (pageParam != null) {
        return int.tryParse(pageParam);
      }
    } catch (e) {
      // 忽略解析错误
    }

    return null;
  }

  /// 拉取指定难度的所有页面
  Future<List<ScoreData>> _fetchDifficultyScores(
    InAppWebViewController controller,
    String difficulty,
    int difficultyIndex,
    int currentStep,
    int totalSteps,
  ) async {
    var allDifficultyScores = <ScoreData>[];

    try {
      // 等待DOM元素出现
      bool domReady = false;
      for (int i = 0; i < 15; i++) {
        final checkDom = await controller.evaluateJavascript(
          source: '''
          (function() {
            const diffSelectors = document.querySelectorAll('.difficulty-selector');
            const cards = document.querySelectorAll('.list-card .card-container');
            return diffSelectors.length > 0 && cards.length > 0;
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

      final clickResult = await controller.evaluateJavascript(
        source: clickScript,
      );

      if (clickResult == false) {
        return [];
      }

      // 如果难度已经激活，不需要等待太久
      if (clickResult == 'already_active') {
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        // 等待Vue重新渲染
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // 开始拉取所有页面
      int currentPage = 1;
      bool hasMore = true;
      int consecutiveEmptyPages = 0;
      int consecutiveFailedUpdates = 0;

      while (hasMore && _isFetching) {
        // 更新进度
        final progress =
            (currentStep + (currentPage / 20.0).clamp(0.0, 0.95)) / totalSteps;
        _progressStreamController.add(progress);

        // 记录当前页面第一首歌的标题
        final firstSongTitle = await _getFirstSongTitle(controller);

        // 解析当前页面数据
        final parseScript = _getParseScript(difficulty);
        final result = await controller.evaluateJavascript(
          source: parseScript,
        );

        if (result != null && result is String && result.isNotEmpty) {
          try {
            final data = jsonDecode(result);
            final playerPTTValue = data['playerPTT'];
            double? parsedPTT;
            if (playerPTTValue is num) {
              parsedPTT = playerPTTValue.toDouble();
            } else if (playerPTTValue is String) {
              parsedPTT = double.tryParse(playerPTTValue);
            }

            if (parsedPTT != null && _latestPlayerPTT != parsedPTT) {
              _latestPlayerPTT = parsedPTT;
              await _storageService.savePlayerPTT(parsedPTT);
            }
            var scores = (data['scores'] as List<dynamic>)
                .map((e) => ScoreData.fromJson(e as Map<String, dynamic>))
                .toList();

            // 针对 ETR 和 BYD 难度进行额外校验
            if (difficulty == 'BYD' || difficulty == 'ETR') {
              scores = scores.where((score) {
                return _songDataService.hasDifficulty(
                  score.songTitle,
                  difficulty,
                );
              }).toList();
            }

            if (scores.isEmpty) {
              consecutiveEmptyPages++;
              if (consecutiveEmptyPages >= 2) {
                hasMore = false;
                break;
              }
            } else {
              consecutiveEmptyPages = 0;

              if (_isUpdateMode) {
                bool foundExistingDate = false;
                List<ScoreData> newScores = [];

                for (var score in scores) {
                  if (_existingDates.contains(score.obtainedDate)) {
                    foundExistingDate = true;
                    break;
                  }
                  newScores.add(score);
                }

                if (newScores.isNotEmpty) {
                  allDifficultyScores.addAll(newScores);
                  allDifficultyScores = _deduplicateScores(allDifficultyScores);
                }

                if (foundExistingDate) {
                  hasMore = false;
                  break;
                }
              } else {
                allDifficultyScores.addAll(scores);
                allDifficultyScores = _deduplicateScores(allDifficultyScores);
              }
            }

            // 更新UI
            _scoreStreamController.add(
              ScoreListResponse(
                scores: List.from(_allScores)..addAll(allDifficultyScores),
                currentPage: currentPage,
                hasNextPage: data['hasNextPage'] as bool,
                playerPTT: _latestPlayerPTT,
              ),
            );

            hasMore = data['hasNextPage'] as bool;

            if (hasMore) {
              final currentUrl = await controller.getUrl();
              final currentPageNum = _extractPageNumber(currentUrl?.toString());

              // 点击下一页按钮
              final nextPageResult = await _clickNextPageButton(controller);
              if (!nextPageResult) {
                hasMore = false;
              } else {
                bool pageUpdated = false;
                for (int i = 0; i < 25; i++) {
                  await Future.delayed(const Duration(milliseconds: 200));
                  final newFirstSongTitle = await _getFirstSongTitle(
                    controller,
                  );

                  if (newFirstSongTitle != firstSongTitle &&
                      newFirstSongTitle.isNotEmpty) {
                    final newUrl = await controller.getUrl();
                    final newPageNum = _extractPageNumber(
                      newUrl?.toString(),
                    );

                    if (newPageNum != null &&
                        currentPageNum != null &&
                        newPageNum <= currentPageNum) {
                      hasMore = false;
                      break;
                    }

                    pageUpdated = true;
                    consecutiveFailedUpdates = 0;
                    break;
                  }
                }

                if (!pageUpdated) {
                  consecutiveFailedUpdates++;
                  if (consecutiveFailedUpdates >= 2) {
                    hasMore = false;
                  }
                } else if (hasMore) {
                  currentPage++;
                }
              }
            }
          } catch (e) {
            hasMore = false;
          }
        } else {
          hasMore = false;
        }
      }

      return allDifficultyScores;
    } catch (e) {
      return allDifficultyScores;
    }
  }

  /// 获取当前页面第一首歌的标题
  Future<String> _getFirstSongTitle(InAppWebViewController controller) async {
    try {
      final titleScript = '''
        (function() {
          const firstCard = document.querySelector('.list-card .card-container .card');
          if (firstCard) {
            const titleElement = firstCard.querySelector('.title .no-overflow');
            return titleElement ? titleElement.textContent.trim() : '';
          }
          return '';
        })();
      ''';

      final result = await controller.evaluateJavascript(source: titleScript);
      return result?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  /// 点击下一页按钮
  Future<bool> _clickNextPageButton(InAppWebViewController controller) async {
    try {
      final clickScript = '''
        (function() {
          try {
            // 方法1: 查找包含SVG图标的翻页按钮（向右的箭头）
            const pageButtons = document.querySelectorAll('span.no-select');
            console.log('[翻页] 找到 ' + pageButtons.length + ' 个no-select元素');
            
            for (let i = 0; i < pageButtons.length; i++) {
              const button = pageButtons[i];
              const img = button.querySelector('img');
              if (img && img.src && img.src.includes('Path_1121')) {
                // 检查SVG的transform属性，rotate(-90)表示向右的箭头
                const svgContent = img.src;
                if (svgContent.includes("rotate(-90)")) {
                  // 检查父元素是否包含disabled类
                  const parent = button.parentElement;
                  if (!parent || !parent.classList.contains('disabled')) {
                    button.click();
                    console.log('[翻页] 已点击下一页按钮（方法1）');
                    return true;
                  }
                }
              }
            }
            
            // 方法2: 使用CSS选择器查找未禁用的下一页按钮
            const nextButton = document.querySelector('.pagination .next:not(.disabled)');
            if (nextButton) {
              nextButton.click();
              console.log('[翻页] 已点击下一页按钮（方法2）');
              return true;
            }
            
            // 方法3: 查找rel="next"的链接
            const nextLink = document.querySelector('a[rel="next"]');
            if (nextLink) {
              nextLink.click();
              console.log('[翻页] 已点击下一页按钮（方法3）');
              return true;
            }
            
            console.log('[翻页] 未找到下一页按钮');
            return false;
          } catch (e) {
            console.error('[翻页] 点击错误:', e);
            return false;
          }
        })();
      ''';

      final result = await controller.evaluateJavascript(source: clickScript);
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// 获取解析页面数据的JavaScript脚本
  String _getParseScript(String difficulty) {
    return '''
(function() {
  try {
    const cardContainers = document.querySelectorAll('.list-card .card-container');
    const scores = [];
    
    console.log('[解析] 找到 ' + cardContainers.length + ' 个卡片容器');
    
    cardContainers.forEach((container, index) => {
      try {
        const card = container.querySelector('.card');
        if (!card) return;
        
        const titleElement = card.querySelector('.title .no-overflow');
        const songTitle = titleElement ? titleElement.textContent.trim() : '';
        
        const artistElements = card.querySelectorAll('.header-ta');
        let artist = '';
        if (artistElements.length >= 2) {
          const artistSpan = artistElements[1].querySelector('.no-overflow');
          artist = artistSpan ? artistSpan.textContent.trim() : '';
        }
        
        const expElement = card.querySelector('.experince .ex-main');
        let score = 0;
        let grade = '';
        if (expElement) {
          const gradeElement = expElement.querySelector('span');
          grade = gradeElement ? gradeElement.textContent.trim() : '';
          const scoreText = expElement.textContent.replace(grade, '').trim().replace(/,/g, '').replace(/\\s/g, '');
          score = parseInt(scoreText) || 0;
        }
        
        const clearElement = card.querySelector('.small-diamond span');
        const clearType = clearElement ? clearElement.textContent.trim() : '';
        
        const dateElements = card.querySelectorAll('.header-ta');
        let obtainedDate = '';
        for (let i = 0; i < dateElements.length; i++) {
          const label = dateElements[i].querySelector('label');
          if (label && label.textContent.includes('取得日期')) {
            const dateSpan = dateElements[i].querySelector('.no-overflow');
            obtainedDate = dateSpan ? dateSpan.textContent.trim() : '';
            break;
          }
        }
        
        const albumElement = card.querySelector('.album-jacket');
        const albumArtUrl = albumElement ? albumElement.src : '';
        
        if (songTitle) {
          scores.push({
            songTitle: songTitle,
            artist: artist,
            score: score,
            grade: grade,
            clearType: clearType,
            obtainedDate: obtainedDate,
            albumArtUrl: albumArtUrl,
            difficulty: '$difficulty'
          });
        }
      } catch (e) {
        console.error('[解析] 解析卡片错误:', e);
      }
    });
    
    console.log('[解析] 总共解析了 ' + scores.length + ' 个成绩');
    
    let playerPTT = null;
    const pttElement = document.querySelector('.ptt, [class*="ptt"]');
    if (pttElement) {
      const text = pttElement.textContent.trim().replace(/,/g, '');
      const match = text.match(/([\d.]+)/);
      if (match && match[1]) {
        playerPTT = parseFloat(match[1]);
      }
    }
    
    // 检查是否有下一页按钮
    let hasNextPage = false;
    
    // 方法1: 检查SVG按钮（必须不被禁用）
    const pageButtons = document.querySelectorAll('span.no-select');
    for (let i = 0; i < pageButtons.length; i++) {
      const button = pageButtons[i];
      const img = button.querySelector('img');
      if (img && img.src && img.src.includes('Path_1121')) {
        const svgContent = img.src;
        if (svgContent.includes("rotate(-90)")) {
          // 检查按钮及其父元素是否被禁用
          const parent = button.parentElement;
          const isDisabled = button.classList.contains('disabled') || 
                           (parent && parent.classList.contains('disabled')) ||
                           button.hasAttribute('disabled');
          
          if (!isDisabled) {
            hasNextPage = true;
            console.log('[解析] 通过SVG按钮检测到有下一页');
            break;
          } else {
            console.log('[解析] SVG按钮存在但已被禁用');
          }
        }
      }
    }
    
    // 方法2: 检查CSS选择器（必须存在且未禁用）
    if (!hasNextPage) {
      const nextButton = document.querySelector('.pagination .next:not(.disabled)');
      if (nextButton) {
        hasNextPage = true;
        console.log('[解析] 通过pagination检测到有下一页');
      }
    }
    
    // 方法3: 检查rel="next"链接
    if (!hasNextPage) {
      const nextLink = document.querySelector('a[rel="next"]');
      if (nextLink) {
        hasNextPage = true;
        console.log('[解析] 通过rel=next检测到有下一页');
      }
    }
    
    // 额外检查：如果成绩数为0，强制设置hasNextPage为false
    if (scores.length === 0) {
      hasNextPage = false;
      console.log('[解析] 成绩数为0，强制设置hasNextPage=false');
    }
    
    const result = {
      scores: scores,
      currentPage: 1,
      hasNextPage: hasNextPage,
      playerPTT: playerPTT
    };
    
    console.log('[解析] 返回结果，成绩数: ' + scores.length + ', hasNextPage: ' + hasNextPage);
    return JSON.stringify(result);
  } catch (e) {
    console.error('[解析] 错误:', e);
    return JSON.stringify({scores: [], currentPage: 1, hasNextPage: false});
  }
})();
''';
  }

  /// 清理资源
  void dispose() {
    _isFetching = false;
    _headlessWebView?.dispose();
    _headlessWebView = null;
    _scoreStreamController.close();
    _errorStreamController.close();
    _progressStreamController.close();
    _difficultyStreamController.close();
  }
}
