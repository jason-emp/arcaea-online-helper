import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/friend_score_data.dart';
import '../services/friend_score_fetch_service.dart';
import '../services/friend_score_storage_service.dart';
import '../services/song_data_service.dart';
import 'common/arcaea_widgets.dart';

/// 好友成绩列表页面
class FriendScoreListPage extends StatefulWidget {
  const FriendScoreListPage({super.key});

  @override
  State<FriendScoreListPage> createState() => _FriendScoreListPageState();
}

class _FriendScoreListPageState extends State<FriendScoreListPage> {
  final FriendScoreFetchService _fetchService = FriendScoreFetchService();
  final FriendScoreStorageService _storageService = FriendScoreStorageService();
  final SongDataService _songDataService = SongDataService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<SongFriendScores> _songs = [];
  List<SongFriendScores> _filteredSongs = [];
  String _searchQuery = '';
  String _selectedDifficulty = 'FTR';
  bool _showScrollToTop = false;

  bool _isFetching = false;
  bool _isLoading = true;
  bool _hasFetched = false;
  double _progress = 0.0;
  Map<String, double> _taskProgress = {}; // 各线程进度

  final List<String> _difficulties = ['PST', 'PRS', 'FTR', 'ETR', 'BYD'];

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _loadSongMetadata();
    _loadCachedScores();
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

  void _setupListeners() {
    _fetchService.friendScoreStream.listen((response) {
      if (mounted) {
        setState(() {
          _songs = response.songs;
          _applyFilterAndSort();
        });
      }
    });

    _fetchService.errorStream.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    });

    _fetchService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          if (progress < 0) {
            _isFetching = false;
            _progress = 0.0;
            _taskProgress.clear();
          } else {
            _isFetching = true;
            _progress = progress;
          }
        });
      }
    });

    // 监听各线程进度
    _fetchService.taskProgressStream.listen((taskProgress) {
      if (mounted) {
        setState(() {
          _taskProgress = taskProgress;
        });
      }
    });
  }

  Future<void> _loadSongMetadata() async {
    try {
      await _songDataService.ensureLoaded();
    } catch (e) {
      // 忽略加载错误
    }
  }

  Future<void> _loadCachedScores() async {
    try {
      final songs = await _storageService.loadFriendScores();
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
          _hasFetched = songs.isNotEmpty;
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

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilterAndSort();
    });
  }

  void _applyFilterAndSort() {
    List<SongFriendScores> filtered = _songs;

    // 1. 难度筛选
    filtered = filtered
        .where((song) => song.difficulty == _selectedDifficulty)
        .toList();

    // 2. 搜索过滤
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((song) {
        final titleMatch = song.songTitle.toLowerCase().contains(_searchQuery);
        final artistMatch = song.artist.toLowerCase().contains(_searchQuery);
        // 也可以搜索好友名
        final friendMatch = song.friendScores.any(
          (f) => f.username.toLowerCase().contains(_searchQuery),
        );
        return titleMatch || artistMatch || friendMatch;
      }).toList();
    }

    // 3. 按歌曲标题排序
    filtered.sort((a, b) => a.songTitle.compareTo(b.songTitle));

    _filteredSongs = filtered;
  }

  Future<void> _startFetching() async {
    if (_isFetching) return;
    await _fetchService.startFetching();
    await _loadCachedScores();
  }

  void _stopFetching() {
    _fetchService.stopFetching();
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
        title: const Text('确认清除好友成绩数据'),
        content: const Text('此操作将清除所有已获取的好友成绩数据，确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _fetchService.clearFriendScoreData();
      setState(() {
        _songs = [];
        _filteredSongs = [];
        _hasFetched = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('好友成绩数据已清除')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fetchService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友成绩列表'),
        actions: [
          if (_hasFetched)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '清除数据',
              onPressed: _clearData,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
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
          // 搜索框
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索歌曲、作曲家或好友...',
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 12),

          // 难度选择和拉取按钮
          Row(
            children: [
              Expanded(child: _buildDifficultySelector()),
              const SizedBox(width: 12),
              _buildFetchButton(),
            ],
          ),

          // 进度条
          if (_isFetching) ...[
            const SizedBox(height: 12),
            _buildProgressIndicator(),
          ],

          // 提示信息
          if (!_isFetching) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '只能获取你已游玩并上传成绩的曲目的好友成绩，因此可能显示不全',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _difficulties.map((diff) {
          final isSelected = diff == _selectedDifficulty;
          final color = ArcaeaColors.getDifficultyColor(diff);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(diff),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedDifficulty = diff;
                  _applyFilterAndSort();
                });
              },
              selectedColor: color.withOpacity(0.3),
              checkmarkColor: color,
              labelStyle: TextStyle(
                color: isSelected ? color : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFetchButton() {
    if (_isFetching) {
      return FilledButton.icon(
        onPressed: _stopFetching,
        icon: const Icon(Icons.stop),
        label: const Text('停止'),
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
      );
    }

    return FilledButton.icon(
      onPressed: _startFetching,
      icon: const Icon(Icons.download),
      label: Text(_hasFetched ? '更新' : '拉取'),
    );
  }

  Widget _buildProgressIndicator() {
    return GestureDetector(
      onTap: _showDetailedProgressDialog,
      child: Column(
        children: [
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '正在拉取... ${(_progress * 100).toInt()}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetailedProgressDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 监听进度更新
          _fetchService.taskProgressStream.listen((taskProgress) {
            if (context.mounted) {
              setDialogState(() {});
            }
          });

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.downloading),
                SizedBox(width: 8),
                Text('拉取进度详情'),
              ],
            ),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 总进度
                  _buildProgressRow('总进度', _progress, Colors.blue),
                  const Divider(height: 24),
                  // 各线程进度
                  ..._buildTaskProgressRows(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
              if (_isFetching)
                FilledButton(
                  onPressed: () {
                    _stopFetching();
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('停止拉取'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressRow(String label, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 45,
            child: Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTaskProgressRows() {
    if (_taskProgress.isEmpty) {
      return [const Text('等待任务开始...', style: TextStyle(color: Colors.grey))];
    }

    // 按任务ID排序
    final sortedKeys = _taskProgress.keys.toList()
      ..sort((a, b) {
        // 先按难度排序，再按页码排序
        final aIsFtr = a.startsWith('FTR');
        final bIsFtr = b.startsWith('FTR');
        if (aIsFtr && !bIsFtr) return 1;
        if (!aIsFtr && bIsFtr) return -1;
        return a.compareTo(b);
      });

    return sortedKeys.map((taskId) {
      final progress = _taskProgress[taskId] ?? 0.0;
      final color = _getTaskColor(taskId);
      final isComplete = progress >= 1.0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Row(
                children: [
                  if (isComplete)
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green,
                    )
                  else
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: null,
                        color: color,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      taskId,
                      style: TextStyle(
                        fontSize: 11,
                        color: isComplete ? Colors.green : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isComplete ? Colors.green : color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 45,
              child: Text(
                isComplete ? '完成' : '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: isComplete ? Colors.green : Colors.grey[600],
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getTaskColor(String taskId) {
    if (taskId == 'PST') return Colors.cyan;
    if (taskId == 'PRS') return Colors.green;
    if (taskId.startsWith('FTR')) return Colors.purple;
    if (taskId == 'ETR') return Colors.red;
    if (taskId == 'BYD') return Colors.red[900]!;
    return Colors.blue;
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_songs.isEmpty && !_isFetching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无好友成绩数据',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '点击上方"拉取"按钮获取好友成绩',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_filteredSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '没有找到匹配的歌曲',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _filteredSongs.length,
      itemBuilder: (context, index) {
        return _buildSongCard(_filteredSongs[index]);
      },
    );
  }

  Widget _buildSongCard(SongFriendScores song) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ExpansionTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            song.albumArtUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 56,
                height: 56,
                color: Colors.grey[300],
                child: Icon(
                  Icons.music_note,
                  size: 28,
                  color: Colors.grey[600],
                ),
              );
            },
          ),
        ),
        title: Text(
          song.songTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            DifficultyChip(difficulty: song.difficulty, dense: true),
            const SizedBox(width: 8),
            Text(
              '${song.friendScores.length} 位好友',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: song.friendScores.map((friend) {
                return _buildFriendScoreItem(friend);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendScoreItem(FriendScoreData friend) {
    final gradeColor = ArcaeaColors.getGradeColor(friend.grade);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getRankColor(friend.rank),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 排名
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getRankBadgeColor(friend.rank),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#${friend.rank}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 头像
          ClipOval(
            child: Image.network(
              friend.characterIconUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[300],
                  child: const Icon(Icons.person, size: 24),
                );
              },
            ),
          ),
          const SizedBox(width: 12),

          // 用户名和分数
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  friend.formattedScore,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // 评级
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: gradeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              friend.grade,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.withOpacity(0.1);
      case 2:
        return Colors.grey[400]!.withOpacity(0.1);
      case 3:
        return Colors.orange.withOpacity(0.1);
      default:
        return Colors.grey[200]!.withOpacity(0.3);
    }
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
