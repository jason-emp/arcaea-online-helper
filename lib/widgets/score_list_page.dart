import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/core.dart';
import '../models/b30r10_data.dart';
import '../models/score_data.dart';
import '../models/score_filter.dart';
import '../models/score_sort_option.dart';
import '../services/image_generation_manager.dart';
import '../services/image_generator_service.dart';
import '../services/score_fetch_service.dart';
import '../services/score_storage_service.dart';
import '../services/song_data_service.dart';
import 'difficulty_selector_dialog.dart';
import 'score_filter_dialog.dart';

/// 成绩列表页面
class ScoreListPage extends StatefulWidget {
  final ImageGenerationManager? imageManager;
  final bool isActive;

  const ScoreListPage({super.key, this.imageManager, this.isActive = false});

  @override
  State<ScoreListPage> createState() => _ScoreListPageState();
}

class _ScoreListPageState extends State<ScoreListPage> {
  final ScoreFetchService _fetchService = ScoreFetchService();
  final ScoreStorageService _storageService = ScoreStorageService();
  final SongDataService _songDataService = SongDataService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ScoreData> _scores = [];
  List<ScoreData> _filteredScores = [];
  String _searchQuery = '';
  ScoreSortOption _currentSortOption = ScoreSortOption.dateDescending;
  ScoreFilter _currentFilter = const ScoreFilter();
  bool _showScrollToTop = false;

  bool _isFetching = false;
  bool _isLoading = true;
  bool _hasFetched = false;
  bool _isSongDataReady = false;
  double? _playerPTT;
  ImageGenerationManager? _attachedImageManager;
  Map<String, _B30EntryInfo> _b30Lookup = {};
  B30R10Data? _b30Data;
  double? _best30MinPTT;
  double? _recent10ReplacementPTT;

  @override
  void initState() {
    super.initState();
    _attachImageManager(widget.imageManager);
    _setupListeners();
    _loadSongMetadata();
    _loadCachedScores();
    _loadSortOption();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // 当滚动超过 200 像素时显示回到顶部按钮
    if (_scrollController.offset > 200 && !_showScrollToTop) {
      setState(() {
        _showScrollToTop = true;
      });
    } else if (_scrollController.offset <= 200 && _showScrollToTop) {
      setState(() {
        _showScrollToTop = false;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(ScoreListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageManager != widget.imageManager) {
      _detachImageManager();
      _attachImageManager(widget.imageManager);
    }

    // 每次页面变为活跃状态时，主动同步数据
    if (widget.isActive && !oldWidget.isActive) {
      _handleImageManagerChange();
    }
  }

  void _attachImageManager(ImageGenerationManager? manager) {
    if (manager == null) return;
    _attachedImageManager = manager;
    manager.addListener(_handleImageManagerChange);
    // 立即同步当前数据状态
    _handleImageManagerChange();
    // 如果manager还没有数据，再尝试从缓存加载
    if (manager.cachedData == null) {
      Future.microtask(() => manager.loadFromCache());
    }
  }

  void _detachImageManager() {
    _attachedImageManager?.removeListener(_handleImageManagerChange);
    _attachedImageManager = null;
  }

  void _handleImageManagerChange() {
    final data = _attachedImageManager?.cachedData;
    if (data == null) {
      if (_b30Lookup.isNotEmpty || _b30Data != null) {
        if (mounted) {
          setState(() {
            _b30Lookup = {};
            _b30Data = null;
            _best30MinPTT = null;
            _recent10ReplacementPTT = null;
          });
        } else {
          _b30Lookup = {};
          _b30Data = null;
          _best30MinPTT = null;
          _recent10ReplacementPTT = null;
        }
      }
      return;
    }

    final totalPTT = data.player.totalPTT;
    final lookup = _buildB30Lookup(data);
    final best30Min = _computeMinPTT(data.best30);
    final recentReplacement = data.recent10.isNotEmpty
        ? data.recent10.last.playPTT
        : null;

    if (mounted) {
      setState(() {
        if (totalPTT != null) {
          _playerPTT = totalPTT;
        }
        _b30Lookup = lookup;
        _b30Data = data;
        _best30MinPTT = best30Min;
        _recent10ReplacementPTT = recentReplacement;
      });
    } else {
      if (totalPTT != null) {
        _playerPTT = totalPTT;
      }
      _b30Lookup = lookup;
      _b30Data = data;
      _best30MinPTT = best30Min;
      _recent10ReplacementPTT = recentReplacement;
    }
  }

  Future<void> _loadSongMetadata() async {
    try {
      await _songDataService.ensureLoaded();
      if (mounted) {
        setState(() {
          _isSongDataReady = true;
        });
      }
    } catch (e) {
      // 忽略加载错误
    }
  }

  Map<String, _B30EntryInfo> _buildB30Lookup(B30R10Data data) {
    final map = <String, _B30EntryInfo>{};
    for (final song in data.best30) {
      map[_buildSongKey(song.songTitle, song.difficulty)] = _B30EntryInfo(
        song,
        false,
      );
    }
    for (final song in data.recent10) {
      map[_buildSongKey(song.songTitle, song.difficulty)] = _B30EntryInfo(
        song,
        true,
      );
    }
    return map;
  }

  double? _computeMinPTT(List<SongCardData> songs) {
    final values = songs.map((s) => s.playPTT).whereType<double>().toList()
      ..sort();
    return values.isNotEmpty ? values.first : null;
  }

  Future<void> _loadCachedScores() async {
    try {
      final scores = await _storageService.loadScores();
      final cachedPTT = await _storageService.getPlayerPTT();

      if (mounted) {
        setState(() {
          _scores = scores;
          _isLoading = false;
          _hasFetched = scores.isNotEmpty;
          _playerPTT = cachedPTT;
          _applyFilterAndSort();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupListeners() {
    _fetchService.scoreStream.listen((response) {
      if (mounted) {
        setState(() {
          _scores = response.scores;
          if (response.playerPTT != null) {
            _playerPTT = response.playerPTT;
          }
          _applyFilterAndSort();
        });
      }
    });

    _fetchService.errorStream.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    });

    _fetchService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _isFetching = progress >= 0;
        });
      }
    });
  }

  /// 加载排序选项
  Future<void> _loadSortOption() async {
    final option = await _storageService.loadSortOption();
    if (mounted) {
      setState(() {
        _currentSortOption = option;
      });
    }
  }

  /// 保存排序选项
  Future<void> _saveSortOption(ScoreSortOption option) async {
    await _storageService.saveSortOption(option);
    if (mounted) {
      setState(() {
        _currentSortOption = option;
        _applyFilterAndSort();
      });
    }
  }

  /// 搜索文本变化处理
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilterAndSort();
    });
  }

  /// 应用搜索过滤和排序
  void _applyFilterAndSort() {
    // 1. 先过滤（搜索）
    List<ScoreData> filtered = _scores;
    if (_searchQuery.isNotEmpty) {
      filtered = _scores.where((score) {
        final titleMatch = score.songTitle.toLowerCase().contains(_searchQuery);
        final artistMatch = score.artist.toLowerCase().contains(_searchQuery);
        return titleMatch || artistMatch;
      }).toList();
    }

    // 2. 再应用筛选条件
    filtered = _applyFilter(filtered, _currentFilter);

    // 3. 最后排序
    _filteredScores = _sortScores(filtered, _currentSortOption);
  }

  /// 应用筛选条件
  List<ScoreData> _applyFilter(List<ScoreData> scores, ScoreFilter filter) {
    if (!filter.hasAnyFilter) {
      return scores;
    }

    return scores.where((score) {
      // 难度筛选
      if (filter.difficulties.isNotEmpty &&
          !filter.difficulties.contains(score.difficulty)) {
        return false;
      }

      // 曲包筛选
      if (filter.packs.isNotEmpty) {
        final pack = _songDataService.getPackBySongTitle(score.songTitle);
        if (pack == null || !filter.packs.contains(pack)) {
          return false;
        }
      }

      // 获取谱面定数
      final constant = _getScoreConstant(score);

      // 谱面定数筛选
      if (filter.constantMin != null) {
        if (constant == null || constant < filter.constantMin!) {
          return false;
        }
      }
      if (filter.constantMax != null) {
        if (constant == null || constant > filter.constantMax!) {
          return false;
        }
      }

      // 单曲PTT筛选
      if (filter.pttMin != null || filter.pttMax != null) {
        final ptt = _getScorePlayPTT(score);
        if (filter.pttMin != null) {
          if (ptt == null || ptt < filter.pttMin!) {
            return false;
          }
        }
        if (filter.pttMax != null) {
          if (ptt == null || ptt > filter.pttMax!) {
            return false;
          }
        }
      }

      // 成绩筛选
      if (filter.scoreMin != null && score.score < filter.scoreMin!) {
        return false;
      }
      if (filter.scoreMax != null && score.score > filter.scoreMax!) {
        return false;
      }

      // 目标筛选
      if (filter.onlyWithTarget ||
          filter.targetMin != null ||
          filter.targetMax != null) {
        final target = _getScoreTarget(score);

        if (filter.onlyWithTarget && target == null) {
          return false;
        }

        if (filter.targetMin != null) {
          if (target == null || target < filter.targetMin!) {
            return false;
          }
        }
        if (filter.targetMax != null) {
          if (target == null || target > filter.targetMax!) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  /// 解析日期字符串，支持多种格式
  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    // 先判断日期格式的类型，避免 yyyy/M/d 被误解析为儒略日
    final bool usesSlash = dateStr.contains('/');
    final bool usesDash = dateStr.contains('-');
    final bool hasTime = dateStr.contains(':');

    // 根据分隔符和是否有时间来选择格式
    List<String> formats;

    if (usesSlash && !usesDash) {
      // 斜杠格式
      final parts = dateStr.split(RegExp(r'[/\s:]'));
      if (parts.isNotEmpty && parts[0].length == 4) {
        // yyyy/M/d 格式（年份在前）
        if (hasTime) {
          formats = [
            'yyyy/MM/dd HH:mm', // 2024/01/15 13:45
            'yyyy/MM/dd H:mm', // 2024/01/15 1:45
            'yyyy/M/d HH:mm', // 2024/1/15 13:45
            'yyyy/M/d H:mm', // 2024/1/15 1:45
          ];
        } else {
          formats = [
            'yyyy/MM/dd', // 2024/01/15
            'yyyy/M/d', // 2024/1/15
          ];
        }
      } else {
        // M/d/yyyy 格式（月份在前）
        if (hasTime) {
          formats = [
            'M/d/yyyy HH:mm', // 1/15/2024 13:45
            'M/d/yyyy H:mm', // 1/15/2024 1:45
          ];
        } else {
          formats = ['M/d/yyyy']; // 1/15/2024
        }
      }
    } else if (usesDash && !usesSlash) {
      // 破折号格式
      if (hasTime) {
        formats = [
          'yyyy-MM-dd HH:mm', // 2024-01-15 13:45
          'yyyy-MM-dd H:mm', // 2024-01-15 1:45
          'yyyy-M-d HH:mm', // 2024-1-15 13:45
          'yyyy-M-d H:mm', // 2024-1-15 1:45
        ];
      } else {
        formats = [
          'yyyy-MM-dd', // 2024-01-15
          'yyyy-M-d', // 2024-1-15
        ];
      }
    } else {
      // 混合格式或其他情况，尝试所有格式
      formats = [
        'M/d/yyyy HH:mm',
        'M/d/yyyy H:mm',
        'M/d/yyyy',
        'yyyy-MM-dd HH:mm',
        'yyyy-MM-dd H:mm',
        'yyyy-MM-dd',
        'yyyy-M-d HH:mm',
        'yyyy-M-d H:mm',
        'yyyy-M-d',
        'yyyy/MM/dd HH:mm',
        'yyyy/MM/dd H:mm',
        'yyyy/MM/dd',
        'yyyy/M/d HH:mm',
        'yyyy/M/d H:mm',
        'yyyy/M/d',
      ];
    }

    // 尝试解析
    for (final format in formats) {
      try {
        final date = DateFormat(format).parseStrict(dateStr);
        // 验证解析结果的合理性（年份应该在1900-2100之间）
        if (date.year >= 1900 && date.year <= 2100) {
          return date;
        }
      } catch (e) {
        // 继续尝试下一个格式
      }
    }

    return null; // 所有格式都失败
  }

  /// 排序成绩列表
  List<ScoreData> _sortScores(List<ScoreData> scores, ScoreSortOption option) {
    final sorted = List<ScoreData>.from(scores);

    switch (option) {
      case ScoreSortOption.dateDescending:
        // 按日期倒序（最新在前）
        sorted.sort((a, b) {
          final dateA = _parseDate(a.obtainedDate);
          final dateB = _parseDate(b.obtainedDate);

          // 如果两个日期都解析失败，使用字符串比较
          if (dateA == null && dateB == null) {
            return b.obtainedDate.compareTo(a.obtainedDate);
          }
          // 如果A解析失败，A排后面
          if (dateA == null) return 1;
          // 如果B解析失败，B排后面
          if (dateB == null) return -1;

          // 两个日期都解析成功，按日期比较（倒序）
          return dateB.compareTo(dateA);
        });
        break;

      case ScoreSortOption.songTitle:
        // 按曲名
        sorted.sort(
          (a, b) =>
              a.songTitle.toLowerCase().compareTo(b.songTitle.toLowerCase()),
        );
        break;

      case ScoreSortOption.constant:
        // 按定数
        sorted.sort((a, b) {
          final constA = _getScoreConstant(a) ?? -1.0;
          final constB = _getScoreConstant(b) ?? -1.0;
          return constB.compareTo(constA);
        });
        break;

      case ScoreSortOption.pttDescending:
        // 按单曲PTT倒序
        sorted.sort((a, b) {
          final pttA = _getScorePlayPTT(a) ?? -1.0;
          final pttB = _getScorePlayPTT(b) ?? -1.0;
          return pttB.compareTo(pttA);
        });
        break;

      case ScoreSortOption.scoreDescending:
        // 按成绩倒序
        sorted.sort((a, b) => b.score.compareTo(a.score));
        break;

      case ScoreSortOption.scoreAscending:
        // 按成绩顺序
        sorted.sort((a, b) => a.score.compareTo(b.score));
        break;

      case ScoreSortOption.targetAscending:
        // 按目标顺序（没有目标的放最后）
        sorted.sort((a, b) {
          final targetA = _getScoreTarget(a);
          final targetB = _getScoreTarget(b);

          // 如果两个都没有目标，保持原顺序
          if (targetA == null && targetB == null) return 0;
          // 如果 a 没有目标，a 排后面
          if (targetA == null) return 1;
          // 如果 b 没有目标，b 排后面
          if (targetB == null) return -1;
          // 都有目标时，按目标分数从小到大排序
          return targetA.compareTo(targetB);
        });
        break;

      case ScoreSortOption.targetDescending:
        // 按目标倒序（没有目标的放最后）
        sorted.sort((a, b) {
          final targetA = _getScoreTarget(a);
          final targetB = _getScoreTarget(b);

          // 如果两个都没有目标，保持原顺序
          if (targetA == null && targetB == null) return 0;
          // 如果 a 没有目标，a 排后面
          if (targetA == null) return 1;
          // 如果 b 没有目标，b 排后面
          if (targetB == null) return -1;
          // 都有目标时，按目标分数从大到小排序
          return targetB.compareTo(targetA);
        });
        break;

      case ScoreSortOption.targetDiffAscending:
        // 按目标与分数之差顺序（没有目标的放最后）
        sorted.sort((a, b) {
          final diffA = _getScoreTargetDiff(a);
          final diffB = _getScoreTargetDiff(b);

          // 如果两个都没有目标差，保持原顺序
          if (diffA == null && diffB == null) return 0;
          // 如果 a 没有目标差，a 排后面
          if (diffA == null) return 1;
          // 如果 b 没有目标差，b 排后面
          if (diffB == null) return -1;
          // 都有目标差时，按差值从小到大排序
          return diffA.compareTo(diffB);
        });
        break;

      case ScoreSortOption.targetDiffDescending:
        // 按目标与分数之差倒序（没有目标的放最后）
        sorted.sort((a, b) {
          final diffA = _getScoreTargetDiff(a);
          final diffB = _getScoreTargetDiff(b);

          // 如果两个都没有目标差，保持原顺序
          if (diffA == null && diffB == null) return 0;
          // 如果 a 没有目标差，a 排后面
          if (diffA == null) return 1;
          // 如果 b 没有目标差，b 排后面
          if (diffB == null) return -1;
          // 都有目标差时，按差值从大到小排序
          return diffB.compareTo(diffA);
        });
        break;
    }

    return sorted;
  }

  /// 获取成绩的定数
  double? _getScoreConstant(ScoreData score) {
    final cardKey = _buildSongKey(score.songTitle, score.difficulty);
    final entryInfo = _b30Lookup[cardKey];
    return entryInfo?.data.constant ??
        (_isSongDataReady
            ? _songDataService.getConstant(score.songTitle, score.difficulty)
            : null);
  }

  /// 获取成绩的单曲PTT
  double? _getScorePlayPTT(ScoreData score) {
    final constant = _getScoreConstant(score);
    if (constant == null) return null;

    final cardKey = _buildSongKey(score.songTitle, score.difficulty);
    final entryInfo = _b30Lookup[cardKey];
    return entryInfo?.data.playPTT ?? _calculatePlayPTT(score.score, constant);
  }

  /// 获取成绩的目标分数（使用与显示列表相同的逻辑）
  int? _getScoreTarget(ScoreData score) {
    final constant = _getScoreConstant(score);
    if (constant == null || _playerPTT == null) return null;

    final cardKey = _buildSongKey(score.songTitle, score.difficulty);
    final entryInfo = _b30Lookup[cardKey];
    final cardData = entryInfo?.data;

    int? targetScore;

    // 如果在 B30/R10 中，直接计算目标
    if (cardData != null) {
      targetScore = ImageGeneratorService.calculateTargetScore(
        constant,
        score.score,
        _playerPTT,
      );
    }
    // 否则，尝试计算替代 B30 或 R10 的目标
    else if (_best30MinPTT != null || _recent10ReplacementPTT != null) {
      final candidates = <_TargetCandidate>[];

      if (_best30MinPTT != null) {
        final candidate = _calculateReplacementTargetScore(
          constant: constant,
          currentScore: score.score,
          totalPTT: _playerPTT!,
          replacedPTT: _best30MinPTT!,
        );
        if (candidate != null) {
          candidates.add(_TargetCandidate(candidate, 'B30'));
        }
      }

      if (_recent10ReplacementPTT != null) {
        final candidate = _calculateReplacementTargetScore(
          constant: constant,
          currentScore: score.score,
          totalPTT: _playerPTT!,
          replacedPTT: _recent10ReplacementPTT!,
        );
        if (candidate != null) {
          candidates.add(_TargetCandidate(candidate, 'R10'));
        }
      }

      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => a.score.compareTo(b.score));
        targetScore = candidates.first.score;
      }
    }

    return targetScore;
  }

  /// 获取成绩的目标差值
  int? _getScoreTargetDiff(ScoreData score) {
    final target = _getScoreTarget(score);
    if (target == null) return null;
    return target - score.score;
  }

  /// 显示筛选对话框
  Future<void> _showFilterDialog() async {
    final filter = await showDialog<ScoreFilter>(
      context: context,
      builder: (context) => ScoreFilterDialog(initialFilter: _currentFilter),
    );

    if (filter != null && mounted) {
      setState(() {
        _currentFilter = filter;
        _applyFilterAndSort();
      });
    }
  }

  /// 清除筛选条件
  void _clearFilter() {
    setState(() {
      _currentFilter = const ScoreFilter();
      _applyFilterAndSort();
    });
  }

  @override
  void dispose() {
    _fetchService.dispose();
    _detachImageManager();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startFetching() {
    setState(() {
      _scores = [];
    });

    // 显示进度条弹窗
    _showProgressDialog();

    _fetchService.startFetching().then((_) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭进度条弹窗
        setState(() {
          _hasFetched = true;
        });
      }
    });
  }

  Future<void> _startUpdating() async {
    // 显示难度选择对话框
    final selectedDifficulties = await showDialog<List<String>>(
      context: context,
      builder: (context) => const DifficultySelectorDialog(),
    );

    // 如果用户取消选择，则不执行更新
    if (selectedDifficulties == null || selectedDifficulties.isEmpty) {
      return;
    }

    // 显示进度条弹窗
    _showProgressDialog();

    _fetchService.startUpdating(difficulties: selectedDifficulties).then((
      _,
    ) async {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭进度条弹窗
        // 更新完成后重新加载成绩
        await _loadCachedScores();
      }
    });
  }

  void _showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('拉取成绩'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<double>(
                stream: _fetchService.progressStream,
                builder: (context, snapshot) {
                  final progress = snapshot.data;
                  return Column(
                    children: [
                      LinearProgressIndicator(
                        value: (progress != null && progress >= 0)
                            ? progress
                            : null,
                      ),
                      if (progress != null && progress >= 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<String>(
                stream: _fetchService.difficultyStream,
                builder: (context, snapshot) {
                  final difficulty = snapshot.data ?? '';
                  return StreamBuilder<ScoreListResponse>(
                    stream: _fetchService.scoreStream,
                    builder: (context, scoreSnapshot) {
                      final page = scoreSnapshot.data?.currentPage ?? 1;
                      return Text(
                        difficulty.isNotEmpty
                            ? '正在拉取 $difficulty 难度第 $page 页...'
                            : '准备中...',
                        textAlign: TextAlign.center,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              StreamBuilder<ScoreListResponse>(
                stream: _fetchService.scoreStream,
                builder: (context, snapshot) {
                  final count = snapshot.data?.scores.length ?? _scores.length;
                  return Text(
                    '已获取 $count 条成绩',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _fetchService.stopFetching();
                Navigator.of(context).pop();
              },
              child: const Text('停止'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存的成绩数据吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _storageService.clearCache();
        setState(() {
          _scores = [];
          _hasFetched = false;
          _playerPTT = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('缓存已清除')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('清除失败: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成绩列表'),
        actions: [
          // 筛选按钮
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: '筛选',
                onPressed: _showFilterDialog,
              ),
              if (_currentFilter.hasAnyFilter)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          // 排序菜单
          PopupMenuButton<ScoreSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: '排序方式',
            onSelected: _saveSortOption,
            itemBuilder: (context) => ScoreSortOption.values.map((option) {
              return PopupMenuItem<ScoreSortOption>(
                value: option,
                child: Row(
                  children: [
                    if (option == _currentSortOption)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(option.label),
                          Text(
                            option.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          // 更多菜单
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearCache();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('清除缓存'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索曲名或曲师...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // 筛选状态显示
          if (_currentFilter.hasAnyFilter)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.filter_alt,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '已应用筛选条件',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _clearFilter,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('清除', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _currentFilter
                        .getActiveFilterDescriptions()
                        .map(
                          (desc) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              desc,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          // 成绩列表
          Expanded(child: _buildScoreList()),
        ],
      ),
      floatingActionButton: _isFetching
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 回到顶部按钮
                if (_showScrollToTop)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FloatingActionButton(
                      heroTag: 'scrollToTop',
                      onPressed: _scrollToTop,
                      child: const Icon(Icons.arrow_upward),
                    ),
                  ),
                // 拉取/更新成绩按钮
                FloatingActionButton.extended(
                  heroTag: 'fetchScores',
                  onPressed: _hasFetched ? _startUpdating : _startFetching,
                  icon: Icon(_hasFetched ? Icons.refresh : Icons.download),
                  label: Text(_hasFetched ? '更新成绩' : '拉取成绩'),
                ),
              ],
            ),
    );
  }

  Widget _buildScoreList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_scores.isEmpty && !_isFetching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无成绩数据',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮开始拉取',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_filteredScores.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的成绩',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试其他关键词',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _filteredScores.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final score = _filteredScores[index];
        final cardKey = _buildSongKey(score.songTitle, score.difficulty);
        final entryInfo = _b30Lookup[cardKey];
        final cardData = entryInfo?.data;

        final constant =
            cardData?.constant ??
            (_isSongDataReady
                ? _songDataService.getConstant(
                    score.songTitle,
                    score.difficulty,
                  )
                : null);
        final playPTT =
            cardData?.playPTT ??
            ((constant != null)
                ? _calculatePlayPTT(score.score, constant)
                : null);

        int? targetScore;
        String? targetSource;

        if (cardData != null && constant != null && _playerPTT != null) {
          targetScore = ImageGeneratorService.calculateTargetScore(
            constant,
            score.score,
            _playerPTT,
          );
          if (targetScore != null) {
            targetSource = entryInfo?.isRecent == true ? 'R10' : 'B30';
          }
        } else if (constant != null &&
            _playerPTT != null &&
            (_best30MinPTT != null || _recent10ReplacementPTT != null)) {
          final candidates = <_TargetCandidate>[];

          if (_best30MinPTT != null) {
            final candidate = _calculateReplacementTargetScore(
              constant: constant,
              currentScore: score.score,
              totalPTT: _playerPTT!,
              replacedPTT: _best30MinPTT!,
            );
            if (candidate != null) {
              candidates.add(_TargetCandidate(candidate, 'B30'));
            }
          }

          if (_recent10ReplacementPTT != null) {
            final candidate = _calculateReplacementTargetScore(
              constant: constant,
              currentScore: score.score,
              totalPTT: _playerPTT!,
              replacedPTT: _recent10ReplacementPTT!,
            );
            if (candidate != null) {
              candidates.add(_TargetCandidate(candidate, 'R10'));
            }
          }

          if (candidates.isNotEmpty) {
            candidates.sort((a, b) => a.score.compareTo(b.score));
            targetScore = candidates.first.score;
            targetSource = candidates.first.source;
          }
        }

        return _ScoreCard(
          score: score,
          constant: constant,
          playPTT: playPTT,
          targetScore: targetScore,
          targetSource: targetSource,
        );
      },
    );
  }

  double? _calculatePlayPTT(int score, double constant) {
    return PTTCalculator.calculatePlayPTT(score, constant);
  }

  int? _calculateReplacementTargetScore({
    required double constant,
    required int currentScore,
    required double totalPTT,
    required double replacedPTT,
  }) {
    return PTTCalculator.calculateReplacementTargetScore(
      constant: constant,
      currentScore: currentScore,
      totalPTT: totalPTT,
      replacedPTT: replacedPTT,
    );
  }

  String _buildSongKey(String title, String difficulty) {
    return '${title.trim().toLowerCase()}|${difficulty.trim().toUpperCase()}';
  }
}

class _TargetCandidate {
  final int score;
  final String source;

  _TargetCandidate(this.score, this.source);
}

class _B30EntryInfo {
  final SongCardData data;
  final bool isRecent;

  _B30EntryInfo(this.data, this.isRecent);
}

/// 成绩卡片组件
class _ScoreCard extends StatelessWidget {
  final ScoreData score;
  final double? constant;
  final double? playPTT;
  final int? targetScore;
  final String? targetSource;

  const _ScoreCard({
    required this.score,
    this.constant,
    this.playPTT,
    this.targetScore,
    this.targetSource,
  });

  Color _getGradeColor(String grade) {
    return ArcaeaColors.getGradeColor(grade);
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
    Color? valueColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final chipColor = scheme.surfaceContainerHighest.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: valueColor ?? scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatScoreValue(int score) {
    return Formatters.formatScoreWithCommas(score);
  }

  Color _getDifficultyColor(String difficulty) {
    return ArcaeaColors.getDifficultyColor(difficulty);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 专辑封面
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                score.albumArtUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.music_note,
                      size: 40,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),

            // 成绩信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    score.songTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // 作者
                  Text(
                    score.artist,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // 难度和定数
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(score.difficulty),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          score.difficulty,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (constant != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '定数 ${constant!.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 分数和评级
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getGradeColor(score.grade),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          score.grade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        score.formattedScore,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (score.clearType.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.purple),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            score.clearType,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (playPTT != null || targetScore != null) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (playPTT != null)
                          _buildInfoChip(
                            context,
                            label: '单曲 PTT',
                            value: playPTT!.toStringAsFixed(4),
                            icon: Icons.data_exploration,
                          ),
                        if (targetScore != null)
                          _buildInfoChip(
                            context,
                            label: targetSource != null
                                ? '目标分数 ($targetSource)'
                                : '目标分数',
                            value: _formatScoreValue(targetScore!),
                            icon: Icons.flag_outlined,
                            valueColor: Colors.green[700],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  // 日期
                  Text(
                    score.obtainedDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
