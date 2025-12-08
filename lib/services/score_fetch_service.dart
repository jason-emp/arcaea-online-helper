import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/score_data.dart';
import 'score_storage_service.dart';

/// 成绩拉取服务
/// 使用WebView从官网拉取成绩数据
class ScoreFetchService {
  HeadlessInAppWebView? _headlessWebView;
  final _scoreStreamController = StreamController<ScoreListResponse>.broadcast();
  final _errorStreamController = StreamController<String>.broadcast();
  final _progressStreamController = StreamController<double>.broadcast();
  final _difficultyStreamController = StreamController<String>.broadcast();
  final _storageService = ScoreStorageService();

  Stream<ScoreListResponse> get scoreStream => _scoreStreamController.stream;
  Stream<String> get errorStream => _errorStreamController.stream;
  Stream<double> get progressStream => _progressStreamController.stream;
  Stream<String> get difficultyStream => _difficultyStreamController.stream;

  bool _isFetching = false;
  List<ScoreData> _allScores = [];
  final List<String> _difficulties = ['PST', 'PRS', 'FTR', 'ETR', 'BYD'];
  bool _isUpdateMode = false;
  Set<String> _existingDates = {};

  /// 开始增量更新成绩
  /// 只拉取新成绩，遇到已有日期的成绩时停止
  Future<void> startUpdating() async {
    if (_isFetching) {
      _errorStreamController.add('正在拉取中,请稍候');
      return;
    }

    _isFetching = true;
    _isUpdateMode = true;
    
    // 加载已有成绩的日期集合
    final existingScores = await _storageService.loadScores();
    _existingDates = existingScores.map((s) => s.obtainedDate).toSet();
    print('[ScoreFetch] 增量更新模式，已有 ${_existingDates.length} 个不同的日期');

    try {
      // 遍历所有难度
      for (int diffIndex = 0; diffIndex < _difficulties.length; diffIndex++) {
        if (!_isFetching) break;
        
        final difficulty = _difficulties[diffIndex];
        print('[ScoreFetch] 增量更新难度: $difficulty');
        
        // 发送当前难度信息
        _difficultyStreamController.add(difficulty);
        
        // 拉取该难度的新成绩
        final difficultyScores = await _fetchAllPagesForDifficulty(difficulty, diffIndex);
        
        if (difficultyScores.isEmpty) {
          print('[ScoreFetch] 难度 $difficulty 没有新成绩');
        } else {
          print('[ScoreFetch] 难度 $difficulty 共拉取 ${difficultyScores.length} 条新成绩');
          
          // 追加新成绩（使用存储服务的合并去重功能）
          await _storageService.appendScores(difficultyScores);
          
          // 重新加载所有成绩以更新UI
          _allScores = await _storageService.loadScores();
        }
        
        print('[ScoreFetch] 难度 $difficulty 增量更新完成');
        
        // 难度之间延迟
        if (diffIndex < _difficulties.length - 1 && _isFetching) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }

      _isFetching = false;
      _isUpdateMode = false;
      _existingDates.clear();
      _progressStreamController.add(-1); // 完成标记
      print('[ScoreFetch] 所有难度增量更新完成，总计 ${_allScores.length} 条成绩');
    } catch (e) {
      _isFetching = false;
      _isUpdateMode = false;
      _existingDates.clear();
      _errorStreamController.add('更新错误: $e');
      _progressStreamController.add(-1);
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
      // 遍历所有难度
      for (int diffIndex = 0; diffIndex < _difficulties.length; diffIndex++) {
        if (!_isFetching) break;
        
        final difficulty = _difficulties[diffIndex];
        print('[ScoreFetch] 开始拉取难度: $difficulty');
        
        // 发送当前难度信息
        _difficultyStreamController.add(difficulty);
        
        // 拉取该难度的所有页面
        final difficultyScores = await _fetchAllPagesForDifficulty(difficulty, diffIndex);
        
        if (difficultyScores.isEmpty) {
          print('[ScoreFetch] 难度 $difficulty 没有成绩数据');
        } else {
          print('[ScoreFetch] 难度 $difficulty 共拉取 ${difficultyScores.length} 条成绩');
          
          // 添加前先去重（防止与已有成绩重复）
          final beforeCount = _allScores.length;
          _allScores.addAll(difficultyScores);
          _allScores = _deduplicateScores(_allScores);
          final afterCount = _allScores.length;
          final addedCount = afterCount - beforeCount;
          
          print('[ScoreFetch] 去重后实际新增 $addedCount 条成绩（总计 $afterCount 条）');
          
          // 保存到本地存储
          await _storageService.saveScores(_allScores);
        }
        
        print('[ScoreFetch] 难度 $difficulty 拉取完成');
        
        // 难度之间延迟
        if (diffIndex < _difficulties.length - 1 && _isFetching) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }

      // 最终去重并保存
      _allScores = _deduplicateScores(_allScores);
      await _storageService.saveScores(_allScores);
      
      _isFetching = false;
      _progressStreamController.add(-1); // 完成标记
      print('[ScoreFetch] 所有难度拉取完成，去重后总计 ${_allScores.length} 条成绩');
    } catch (e) {
      _isFetching = false;
      _errorStreamController.add('拉取错误: $e');
      _progressStreamController.add(-1);
    }
  }

  /// 停止拉取
  void stopFetching() {
    _isFetching = false;
  }

  /// 成绩去重
  /// 去重规则：歌曲标题 + 难度 + 分数 + 取得日期 完全相同则认为是重复
  List<ScoreData> _deduplicateScores(List<ScoreData> scores) {
    final Map<String, ScoreData> scoreMap = {};
    
    for (var score in scores) {
      // 生成唯一键：歌曲标题_难度_分数_日期
      final key = '${score.songTitle}_${score.difficulty}_${score.score}_${score.obtainedDate}';
      
      // 如果key已存在，保留分数更高的那个（或者保留最新的）
      if (scoreMap.containsKey(key)) {
        // 这里可以添加更复杂的逻辑，比如保留分数更高的
        // 但按照去重规则，分数和日期都相同，所以直接跳过即可
        continue;
      }
      
      scoreMap[key] = score;
    }
    
    final deduplicated = scoreMap.values.toList();
    if (deduplicated.length < scores.length) {
      print('[ScoreFetch] 去重：${scores.length} 条 -> ${deduplicated.length} 条（移除 ${scores.length - deduplicated.length} 条重复）');
    }
    
    return deduplicated;
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
      print('[ScoreFetch] 解析URL失败: $e');
    }
    
    return null;
  }

  /// 拉取指定难度的所有页面（包括第一页和后续页面）
  Future<List<ScoreData>> _fetchAllPagesForDifficulty(String difficulty, int difficultyIndex) async {
    var allDifficultyScores = <ScoreData>[]; // 改为var以便重新赋值
    final completer = Completer<List<ScoreData>>();
    final url = 'https://arcaea.lowiro.com/zh/profile/scores?page=1';

    try {
      _headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        ),
        onLoadStop: (controller, url) async {
          try {
            print('[ScoreFetch] 页面加载完成，等待DOM渲染...');
            
            // 等待DOM加载
            await Future.delayed(const Duration(milliseconds: 2000));
            
            // 等待DOM元素出现
            bool domReady = false;
            for (int i = 0; i < 20; i++) {
              await Future.delayed(const Duration(milliseconds: 500));
              
              final checkDom = await controller.evaluateJavascript(source: '''
                (function() {
                  const diffSelectors = document.querySelectorAll('.difficulty-selector');
                  const cards = document.querySelectorAll('.list-card .card-container');
                  return diffSelectors.length > 0 && cards.length > 0;
                })();
              ''');
              
              if (checkDom == true) {
                domReady = true;
                print('[ScoreFetch] DOM已就绪');
                break;
              }
            }
            
            if (!domReady) {
              print('[ScoreFetch] DOM未就绪');
              completer.complete([]);
              return;
            }
            
            await Future.delayed(const Duration(milliseconds: 1000));
            print('[ScoreFetch] 开始切换难度到: $difficulty');

            // 切换到目标难度
            final clickScript = '''
              (function() {
                const diffSelectors = document.querySelectorAll('.difficulty-selector');
                if ($difficultyIndex < diffSelectors.length) {
                  diffSelectors[$difficultyIndex].click();
                  console.log('[切换难度] 已点击索引: $difficultyIndex');
                  return true;
                }
                return false;
              })();
            ''';
            
            final clickResult = await controller.evaluateJavascript(source: clickScript);
            
            if (clickResult != true) {
              print('[ScoreFetch] 切换难度失败');
              completer.complete([]);
              return;
            }
            
            // 等待Vue重新渲染
            await Future.delayed(const Duration(milliseconds: 3000));
            
            // 开始拉取所有页面
            int currentPage = 1;
            bool hasMore = true;
            int consecutiveEmptyPages = 0; // 连续空页计数
            int consecutiveFailedUpdates = 0; // 连续翻页失败计数
            
            while (hasMore && _isFetching) {
              print('[ScoreFetch] 拉取难度 $difficulty 第 $currentPage 页');
              
              // 记录当前页面第一首歌的标题（用于检测页面是否真的更新了）
              final firstSongTitle = await _getFirstSongTitle(controller);
              print('[ScoreFetch] 当前页第一首歌: $firstSongTitle');
              
              // 解析当前页面数据
              final parseScript = _getParseScript(difficulty);
              final result = await controller.evaluateJavascript(source: parseScript);
              
              if (result != null && result is String && result.isNotEmpty) {
                try {
                  final data = jsonDecode(result);
                  final scores = (data['scores'] as List<dynamic>)
                      .map((e) => ScoreData.fromJson(e as Map<String, dynamic>))
                      .toList();
                  
                  print('[ScoreFetch] 第 $currentPage 页解析到 ${scores.length} 条成绩');
                  
                  // 检查是否为空页
                  if (scores.isEmpty) {
                    consecutiveEmptyPages++;
                    print('[ScoreFetch] 连续空页数: $consecutiveEmptyPages');
                    if (consecutiveEmptyPages >= 2) {
                      print('[ScoreFetch] 连续2页为空，认为已到最后一页');
                      hasMore = false;
                      break;
                    }
                  } else {
                    consecutiveEmptyPages = 0;
                    
                    // 如果是增量更新模式，检查是否遇到已有日期的成绩
                    if (_isUpdateMode) {
                      bool foundExistingDate = false;
                      List<ScoreData> newScores = [];
                      
                      for (var score in scores) {
                        if (_existingDates.contains(score.obtainedDate)) {
                          print('[ScoreFetch] 检测到已有日期 ${score.obtainedDate}，停止拉取该难度');
                          foundExistingDate = true;
                          break;
                        }
                        newScores.add(score);
                      }
                      
                      // 只添加新成绩
                      if (newScores.isNotEmpty) {
                        allDifficultyScores.addAll(newScores);
                        allDifficultyScores = _deduplicateScores(allDifficultyScores);
                      }
                      
                      // 如果遇到已有日期，停止拉取该难度
                      if (foundExistingDate) {
                        hasMore = false;
                        break;
                      }
                    } else {
                      // 全量拉取模式，添加所有成绩
                      allDifficultyScores.addAll(scores);
                      allDifficultyScores = _deduplicateScores(allDifficultyScores);
                    }
                  }
                  
                  // 更新UI
                  _scoreStreamController.add(ScoreListResponse(
                    scores: List.from(_allScores)..addAll(allDifficultyScores),
                    currentPage: currentPage,
                    hasNextPage: data['hasNextPage'] as bool,
                  ));
                  
                  hasMore = data['hasNextPage'] as bool;
                  
                  if (hasMore) {
                    // 点击翻页按钮前，记录当前URL的page值
                    final currentUrl = await controller.getUrl();
                    final currentPageNum = _extractPageNumber(currentUrl?.toString());
                    print('[ScoreFetch] 当前URL页码: $currentPageNum');
                    
                    // 点击下一页按钮
                    final nextPageResult = await _clickNextPageButton(controller);
                    if (!nextPageResult) {
                      print('[ScoreFetch] 点击下一页失败，认为已到最后一页');
                      hasMore = false;
                    } else {
                      // 等待页面内容真正更新（通过检查第一首歌标题是否变化）
                      bool pageUpdated = false;
                      for (int i = 0; i < 20; i++) {
                        await Future.delayed(const Duration(milliseconds: 500));
                        final newFirstSongTitle = await _getFirstSongTitle(controller);
                        
                        if (newFirstSongTitle != firstSongTitle && newFirstSongTitle.isNotEmpty) {
                          print('[ScoreFetch] 页面已更新，新页第一首歌: $newFirstSongTitle');
                          
                          // 检查URL的page值是否变小了（循环回第一页的标志）
                          final newUrl = await controller.getUrl();
                          final newPageNum = _extractPageNumber(newUrl?.toString());
                          print('[ScoreFetch] 新URL页码: $newPageNum');
                          
                          if (newPageNum != null && currentPageNum != null && newPageNum <= currentPageNum) {
                            print('[ScoreFetch] 检测到页码循环（$currentPageNum -> $newPageNum），已到最后一页');
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
                        print('[ScoreFetch] 10秒内页面未更新，连续失败次数: $consecutiveFailedUpdates');
                        
                        if (consecutiveFailedUpdates >= 2) {
                          print('[ScoreFetch] 连续2次翻页失败，认为已到最后一页');
                          hasMore = false;
                        }
                      } else if (hasMore) {
                        // 只有在hasMore仍为true时才增加页码
                        currentPage++;
                        
                        // 更新进度
                        final progress = (difficultyIndex * 100 + currentPage) / (_difficulties.length * 100);
                        _progressStreamController.add(progress);
                      }
                    }
                  }
                } catch (e) {
                  print('[ScoreFetch] 解析错误: $e');
                  hasMore = false;
                }
              } else {
                print('[ScoreFetch] 第 $currentPage 页返回空数据');
                hasMore = false;
              }
            }
            
            completer.complete(allDifficultyScores);
          } catch (e) {
            print('[ScoreFetch] 拉取错误: $e');
            completer.complete(allDifficultyScores);
          }
        },
        onLoadError: (controller, url, code, message) {
          print('[ScoreFetch] 加载错误: $message');
          completer.complete([]);
        },
      );

      await _headlessWebView?.run();

      // 等待完成
      final result = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          print('[ScoreFetch] 拉取超时');
          return allDifficultyScores;
        },
      );
      
      // 清理WebView
      await _headlessWebView?.dispose();
      _headlessWebView = null;
      
      return result;
    } catch (e) {
      print('[ScoreFetch] 拉取难度 $difficulty 错误: $e');
      _headlessWebView?.dispose();
      _headlessWebView = null;
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
      print('[ScoreFetch] 获取第一首歌标题错误: $e');
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
      print('[ScoreFetch] 点击翻页按钮错误: $e');
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
      hasNextPage: hasNextPage
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
