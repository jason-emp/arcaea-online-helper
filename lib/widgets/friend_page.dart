import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/friend_data.dart';
import '../services/friend_fetch_service.dart';
import 'friend_score_list_page.dart';
import 'friend_user_score_list_page.dart';

/// 好友页面 - 显示好友列表和数据
class FriendPage extends StatefulWidget {
  const FriendPage({super.key});

  @override
  State<FriendPage> createState() => _FriendPageState();
}

enum FriendSortType {
  none,
  usernameAsc,
  usernameDesc,
  ratingDesc,
  ratingAsc,
  lastActiveAsc,
  lastActiveDesc,
}

class _FriendPageState extends State<FriendPage> {
  final FriendFetchService _fetchService = FriendFetchService();
  final ScrollController _scrollController = ScrollController();

  List<FriendData> _friends = [];
  bool _isFetching = false;
  double _progress = 0.0;
  FriendSortType _currentSort = FriendSortType.none;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _loadCachedData();
  }

  void _setupListeners() {
    _fetchService.friendStream.listen((friends) {
      if (mounted) {
        setState(() {
          _friends = friends;
          _applySorting();
        });
      }
    });

    _fetchService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          if (progress >= 0 && progress <= 1) {
            _progress = progress;
          }
        });
      }
    });

    _fetchService.errorStream.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('错误: $error'), backgroundColor: Colors.red),
        );
        setState(() {
          _isFetching = false;
        });
      }
    });
  }

  Future<void> _loadCachedData() async {
    final cachedFriends = await _fetchService.loadCachedFriends();
    if (cachedFriends.isNotEmpty && mounted) {
      setState(() {
        _friends = cachedFriends;
        _applySorting();
      });
    }
  }

  /// 清除好友缓存数据
  Future<void> _clearFriendData() async {
    await _fetchService.clearFriendData();
    if (mounted) {
      setState(() {
        _friends = [];
        _currentSort = FriendSortType.none;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('好友数据已清除'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 显示清除数据确认对话框
  void _showClearDataConfirmDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
        title: const Text('确认清除好友数据'),
        content: const Text(
          '此操作将永久删除所有好友信息。\n\n'
          '清除后需要重新拉取数据，此操作无法撤销，确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _clearFriendData();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }

  void _applySorting() {
    switch (_currentSort) {
      case FriendSortType.usernameAsc:
        _friends.sort((a, b) => a.username.compareTo(b.username));
        break;
      case FriendSortType.usernameDesc:
        _friends.sort((a, b) => b.username.compareTo(a.username));
        break;
      case FriendSortType.ratingDesc:
        _friends.sort((a, b) => b.ratingValue.compareTo(a.ratingValue));
        break;
      case FriendSortType.ratingAsc:
        _friends.sort((a, b) => a.ratingValue.compareTo(b.ratingValue));
        break;
      case FriendSortType.lastActiveAsc:
        _friends.sort(
          (a, b) => _compareActiveTime(a.lastActiveTime, b.lastActiveTime),
        );
        break;
      case FriendSortType.lastActiveDesc:
        _friends.sort(
          (a, b) => _compareActiveTime(b.lastActiveTime, a.lastActiveTime),
        );
        break;
      case FriendSortType.none:
        // 保持原顺序
        break;
    }
  }

  /// 比较活跃时间 (例如: "15m", "3h", "1d", "1M", "1Y")
  int _compareActiveTime(String a, String b) {
    final int valueA = _parseActiveTimeToMinutes(a);
    final int valueB = _parseActiveTimeToMinutes(b);
    return valueA.compareTo(valueB);
  }

  /// 将活跃时间字符串转换为分钟数
  int _parseActiveTimeToMinutes(String timeStr) {
    final trimmed = timeStr.trim();
    if (trimmed.isEmpty) return 999999999;

    final match = RegExp(r'(\d+)([a-zA-Z]+)').firstMatch(trimmed);
    if (match == null) return 999999999;

    final value = int.tryParse(match.group(1) ?? '') ?? 0;
    final unit = match.group(2)?.toLowerCase() ?? '';

    switch (unit) {
      case 'm':
        return value;
      case 'h':
        return value * 60;
      case 'd':
        return value * 60 * 24;
      case 'w':
        return value * 60 * 24 * 7;
      case 'y':
        return value * 60 * 24 * 365;
      default:
        return 999999999;
    }
  }

  Future<void> _startFetching() async {
    if (_isFetching) return;

    setState(() {
      _isFetching = true;
      _progress = 0.0;
    });

    await _fetchService.startFetching();
    if (mounted) {
      setState(() {
        _isFetching = false;
      });
    }
  }

  Future<void> _showSortOptions() async {
    final result = await showDialog<FriendSortType>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('排序选项'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSortOption(
                dialogContext,
                '用户名 ↑',
                FriendSortType.usernameAsc,
              ),
              _buildSortOption(
                dialogContext,
                '用户名 ↓',
                FriendSortType.usernameDesc,
              ),
              const Divider(),
              _buildSortOption(
                dialogContext,
                'PTT 值 ↓',
                FriendSortType.ratingDesc,
              ),
              _buildSortOption(
                dialogContext,
                'PTT 值 ↑',
                FriendSortType.ratingAsc,
              ),
              const Divider(),
              _buildSortOption(
                dialogContext,
                '最近活跃 ↑',
                FriendSortType.lastActiveAsc,
              ),
              _buildSortOption(
                dialogContext,
                '最近活跃 ↓',
                FriendSortType.lastActiveDesc,
              ),
              const Divider(),
              _buildSortOption(dialogContext, '默认顺序', FriendSortType.none),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _currentSort = result;
        _applySorting();
      });
    }
  }

  Widget _buildSortOption(
    BuildContext dialogContext,
    String label,
    FriendSortType sortType,
  ) {
    final isSelected = _currentSort == sortType;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(label),
      selected: isSelected,
      onTap: () => Navigator.of(dialogContext).pop(sortType),
    );
  }

  String _getSortDescription() {
    switch (_currentSort) {
      case FriendSortType.usernameAsc:
        return '用户名 ↑';
      case FriendSortType.usernameDesc:
        return '用户名 ↓';
      case FriendSortType.ratingDesc:
        return 'PTT ↓';
      case FriendSortType.ratingAsc:
        return 'PTT ↑';
      case FriendSortType.lastActiveAsc:
        return '活跃时间 ↑';
      case FriendSortType.lastActiveDesc:
        return '活跃时间 ↓';
      case FriendSortType.none:
        return '默认顺序';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fetchService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友列表'),
        actions: [
          if (_friends.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: _showSortOptions,
              tooltip: '排序',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isFetching ? null : _startFetching,
            tooltip: '刷新',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _showClearDataConfirmDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('清除数据'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const FriendScoreListPage(),
            ),
          );
        },
        icon: const Icon(Icons.leaderboard),
        label: const Text('好友成绩列表'),
        tooltip: '好友成绩列表',
      ),
    );
  }

  Widget _buildBody() {
    if (_isFetching) {
      return _buildLoadingView();
    }

    if (_friends.isEmpty) {
      return _buildEmptyView();
    }

    return Column(
      children: [
        _buildInfoHeader(),
        Expanded(child: _buildFriendList()),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('正在拉取好友数据...', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0),
            child: LinearProgressIndicator(value: _progress),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toInt()}%',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('暂无好友数据', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '点击右上角刷新按钮拉取好友信息',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _startFetching,
            icon: const Icon(Icons.refresh),
            label: const Text('开始拉取'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '共 ${_friends.length} 位好友',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                FutureBuilder<DateTime?>(
                  future: _fetchService.getLastUpdateTime(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final formatter = DateFormat('yyyy-MM-dd HH:mm');
                      return Text(
                        '最后更新: ${formatter.format(snapshot.data!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          if (_currentSort != FriendSortType.none)
            Chip(
              label: Text(_getSortDescription()),
              avatar: const Icon(Icons.sort, size: 16),
              onDeleted: () {
                setState(() {
                  _currentSort = FriendSortType.none;
                  _applySorting();
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFriendList() {
    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0), // 增加底部边距，避免被大的悬浮按钮遮挡
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          return _buildFriendCard(_friends[index]);
        },
      ),
    );
  }

  Widget _buildFriendCard(FriendData friend) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FriendUserScoreListPage(friend: friend),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 角色头像
              ClipOval(
                child: Image.network(
                  friend.characterIconUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, size: 32),
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
                        Expanded(
                          child: Text(
                            friend.username,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (friend.isMutual)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '互相好友',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      friend.songName,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '最近活跃: ${friend.lastActiveTime}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ),
                        // 点击提示图标
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // PTT 值显示
              _buildRatingDisplay(friend),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingDisplay(FriendData friend) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getRatingColor(friend.ratingClass),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'PTT',
            style: const TextStyle(
              fontSize: 10,
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
                  style: const TextStyle(fontSize: 16),
                ),
                const TextSpan(text: '.', style: TextStyle(fontSize: 14)),
                TextSpan(
                  text: friend.ratingFixed,
                  style: const TextStyle(fontSize: 14),
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
}
