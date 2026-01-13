import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/friend_data.dart';
import '../models/friend_score_data.dart';
import '../services/friend_score_storage_service.dart';
import '../services/song_data_service.dart';
import '../models/score_filter.dart';
import 'score_filter_dialog.dart';

/// 单个好友的成绩数据（用于列表展示）
class FriendUserScoreItem {
  final String songTitle;
  final String artist;
  final String albumArtUrl;
  final String difficulty;
  final int score;
  final String grade;
  final int rank;
  final double? constant;
  final double? playPTT;

  FriendUserScoreItem({
    required this.songTitle,
    required this.artist,
    required this.albumArtUrl,
    required this.difficulty,
    required this.score,
    required this.grade,
    required this.rank,
    this.constant,
    this.playPTT,
  });

  /// 格式化分数显示 (例如: 9,929,880 -> 09,929,880)
  String get formattedScore {
    String scoreStr = score.toString().padLeft(8, '0');
    return '${scoreStr.substring(0, 2)},${scoreStr.substring(2, 5)},${scoreStr.substring(5)}';
  }
}

/// 好友成绩列表页面 - 展示单个好友的所有成绩
class FriendUserScoreListPage extends StatefulWidget {
  final FriendData friend;

  const FriendUserScoreListPage({super.key, required this.friend});

  @override
  State<FriendUserScoreListPage> createState() =>
      _FriendUserScoreListPageState();
}

/// 简化的排序选项（无日期和目标相关）
enum FriendScoreSortOption {
  songTitle('曲名', '按曲名字母顺序排序'),
  constant('定数', '按谱面定数从高到低排序'),
  pttDescending('单曲PTT', '按单曲PTT从高到低排序'),
  scoreDescending('分数降序', '按分数从高到低排序'),
  scoreAscending('分数升序', '按分数从低到高排序');

  final String label;
  final String description;

  const FriendScoreSortOption(this.label, this.description);
}

class _FriendUserScoreListPageState extends State<FriendUserScoreListPage> {
  final FriendScoreStorageService _storageService = FriendScoreStorageService();
  final SongDataService _songDataService = SongDataService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<FriendUserScoreItem> _scores = [];
  List<FriendUserScoreItem> _filteredScores = [];
  String _searchQuery = '';
  FriendScoreSortOption _currentSortOption =
      FriendScoreSortOption.pttDescending;
  ScoreFilter _currentFilter = const ScoreFilter();
  bool _showScrollToTop = false;
  bool _isLoading = true;
  bool _isSongDataReady = false;

  @override
  void initState() {
    super.initState();
    _loadSongMetadata();
    _loadFriendScores();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
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

  Future<void> _loadSongMetadata() async {
    try {
      await _songDataService.ensureLoaded();
      if (mounted) {
        setState(() {
          _isSongDataReady = true;
          // 重新计算定数和PTT
          _enrichScoresWithMetadata();
          _applyFilterAndSort();
        });
      }
    } catch (e) {
      // 忽略加载错误
    }
  }

  Future<void> _loadFriendScores() async {
    try {
      final allSongs = await _storageService.loadFriendScores();
      final friendScores = _extractFriendScores(allSongs);

      if (mounted) {
        setState(() {
          _scores = friendScores;
          _isLoading = false;
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

  /// 从所有歌曲成绩中提取指定好友的成绩
  List<FriendUserScoreItem> _extractFriendScores(
    List<SongFriendScores> allSongs,
  ) {
    final List<FriendUserScoreItem> result = [];

    for (final song in allSongs) {
      for (final friendScore in song.friendScores) {
        if (friendScore.username == widget.friend.username) {
          // 获取定数
          double? constant;
          if (_isSongDataReady) {
            constant = _songDataService.getConstant(
              song.songTitle,
              song.difficulty,
            );
          }

          // 计算单曲PTT
          double? playPTT;
          if (constant != null) {
            playPTT = PTTCalculator.calculatePlayPTT(
              friendScore.score,
              constant,
            );
          }

          result.add(
            FriendUserScoreItem(
              songTitle: song.songTitle,
              artist: song.artist,
              albumArtUrl: song.albumArtUrl,
              difficulty: song.difficulty,
              score: friendScore.score,
              grade: friendScore.grade,
              rank: friendScore.rank,
              constant: constant,
              playPTT: playPTT,
            ),
          );
        }
      }
    }

    return result;
  }

  /// 为成绩添加定数和PTT元数据
  void _enrichScoresWithMetadata() {
    for (int i = 0; i < _scores.length; i++) {
      final score = _scores[i];
      if (score.constant == null && _isSongDataReady) {
        final constant = _songDataService.getConstant(
          score.songTitle,
          score.difficulty,
        );
        if (constant != null) {
          final playPTT = PTTCalculator.calculatePlayPTT(score.score, constant);
          _scores[i] = FriendUserScoreItem(
            songTitle: score.songTitle,
            artist: score.artist,
            albumArtUrl: score.albumArtUrl,
            difficulty: score.difficulty,
            score: score.score,
            grade: score.grade,
            rank: score.rank,
            constant: constant,
            playPTT: playPTT,
          );
        }
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilterAndSort();
    });
  }

  void _applyFilterAndSort() {
    // 1. 搜索过滤
    List<FriendUserScoreItem> filtered = _scores;
    if (_searchQuery.isNotEmpty) {
      filtered = _scores.where((score) {
        final titleMatch = score.songTitle.toLowerCase().contains(_searchQuery);
        final artistMatch = score.artist.toLowerCase().contains(_searchQuery);
        return titleMatch || artistMatch;
      }).toList();
    }

    // 2. 应用筛选条件
    filtered = _applyFilter(filtered, _currentFilter);

    // 3. 排序
    _filteredScores = _sortScores(filtered, _currentSortOption);
  }

  List<FriendUserScoreItem> _applyFilter(
    List<FriendUserScoreItem> scores,
    ScoreFilter filter,
  ) {
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

      // 定数筛选
      if (filter.constantMin != null) {
        if (score.constant == null || score.constant! < filter.constantMin!) {
          return false;
        }
      }
      if (filter.constantMax != null) {
        if (score.constant == null || score.constant! > filter.constantMax!) {
          return false;
        }
      }

      // PTT筛选
      if (filter.pttMin != null) {
        if (score.playPTT == null || score.playPTT! < filter.pttMin!) {
          return false;
        }
      }
      if (filter.pttMax != null) {
        if (score.playPTT == null || score.playPTT! > filter.pttMax!) {
          return false;
        }
      }

      // 分数筛选
      if (filter.scoreMin != null && score.score < filter.scoreMin!) {
        return false;
      }
      if (filter.scoreMax != null && score.score > filter.scoreMax!) {
        return false;
      }

      return true;
    }).toList();
  }

  List<FriendUserScoreItem> _sortScores(
    List<FriendUserScoreItem> scores,
    FriendScoreSortOption option,
  ) {
    final sorted = List<FriendUserScoreItem>.from(scores);

    switch (option) {
      case FriendScoreSortOption.songTitle:
        sorted.sort(
          (a, b) =>
              a.songTitle.toLowerCase().compareTo(b.songTitle.toLowerCase()),
        );
        break;

      case FriendScoreSortOption.constant:
        sorted.sort((a, b) {
          final constA = a.constant ?? -1.0;
          final constB = b.constant ?? -1.0;
          return constB.compareTo(constA);
        });
        break;

      case FriendScoreSortOption.pttDescending:
        sorted.sort((a, b) {
          final pttA = a.playPTT ?? -1.0;
          final pttB = b.playPTT ?? -1.0;
          return pttB.compareTo(pttA);
        });
        break;

      case FriendScoreSortOption.scoreDescending:
        sorted.sort((a, b) => b.score.compareTo(a.score));
        break;

      case FriendScoreSortOption.scoreAscending:
        sorted.sort((a, b) => a.score.compareTo(b.score));
        break;
    }

    return sorted;
  }

  Future<void> _showFilterDialog() async {
    // 使用简化版筛选对话框（不含目标相关选项）
    final filter = await showDialog<ScoreFilter>(
      context: context,
      builder: (context) => ScoreFilterDialog(
        initialFilter: _currentFilter,
        hideTargetFilter: true, // 隐藏目标筛选
      ),
    );

    if (filter != null && mounted) {
      setState(() {
        _currentFilter = filter;
        _applyFilterAndSort();
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _currentFilter = const ScoreFilter();
      _applyFilterAndSort();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.friend.username} 的成绩'),
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
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          // 排序菜单
          PopupMenuButton<FriendScoreSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: '排序方式',
            onSelected: (option) {
              setState(() {
                _currentSortOption = option;
                _applyFilterAndSort();
              });
            },
            itemBuilder: (context) =>
                FriendScoreSortOption.values.map((option) {
                  return PopupMenuItem<FriendScoreSortOption>(
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
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          // 筛选状态显示
          if (_currentFilter.hasAnyFilter) _buildFilterStatusBar(),
          Expanded(child: _buildScoreList()),
        ],
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              mini: true,
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 好友信息卡片
          _buildFriendInfoCard(),
          const SizedBox(height: 12),
          // 搜索框
          TextField(
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
        ],
      ),
    );
  }

  Widget _buildFriendInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 角色头像
          ClipOval(
            child: Image.network(
              widget.friend.characterIconUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[300],
                  child: const Icon(Icons.person, size: 28),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // 好友信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.friend.username,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.friend.isMutual) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '互相好友',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '共 ${_scores.length} 条成绩 · 筛选后 ${_filteredScores.length} 条',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Colors.blue[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '只显示你已游玩的曲目',
                        style: TextStyle(fontSize: 11, color: Colors.blue[600]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // PTT显示
          _buildRatingDisplay(widget.friend),
        ],
      ),
    );
  }

  Widget _buildRatingDisplay(FriendData friend) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getRatingColor(friend.ratingClass),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'PTT',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: friend.ratingDecimal,
                  style: const TextStyle(fontSize: 14),
                ),
                const TextSpan(text: '.', style: TextStyle(fontSize: 12)),
                TextSpan(
                  text: friend.ratingFixed,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(String ratingClass) {
    switch (ratingClass) {
      case 'rating_0':
        return Colors.grey;
      case 'rating_1':
        return Colors.blue;
      case 'rating_2':
        return Colors.green;
      case 'rating_3':
        return Colors.orange;
      case 'rating_4':
        return Colors.red;
      case 'rating_5':
        return Colors.purple;
      case 'rating_6':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFilterStatusBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
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
            children: _currentFilter.getActiveFilterDescriptions().map((desc) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_scores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                '请先在好友成绩列表页拉取数据',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '只能获取你已游玩并上传成绩的曲目的好友成绩',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80), // 增加底部边距，避免被悬浮按钮遮挡
      itemBuilder: (context, index) {
        return _buildScoreCard(_filteredScores[index]);
      },
    );
  }

  Widget _buildScoreCard(FriendUserScoreItem score) {
    final gradeColor = ArcaeaColors.getGradeColor(score.grade);

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
                          color: ArcaeaColors.getDifficultyColor(
                            score.difficulty,
                          ),
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
                      if (score.constant != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '定数 ${score.constant!.toStringAsFixed(1)}',
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
                          color: gradeColor,
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
                      // 排名标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getRankBadgeColor(score.rank),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${score.rank}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 单曲PTT
                  if (score.playPTT != null) ...[
                    _buildInfoChip(
                      context,
                      label: '单曲 PTT',
                      value: score.playPTT!.toStringAsFixed(4),
                      icon: Icons.data_exploration,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Color _getRankBadgeColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber[700]!;
      case 2:
        return Colors.grey[500]!;
      case 3:
        return Colors.orange[700]!;
      default:
        return Colors.grey[600]!;
    }
  }
}
