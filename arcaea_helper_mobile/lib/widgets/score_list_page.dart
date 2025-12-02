import 'package:flutter/material.dart';
import '../models/score_data.dart';
import '../services/score_fetch_service.dart';
import '../services/score_storage_service.dart';
import 'package:intl/intl.dart';

/// 成绩列表页面
class ScoreListPage extends StatefulWidget {
  const ScoreListPage({super.key});

  @override
  State<ScoreListPage> createState() => _ScoreListPageState();
}

class _ScoreListPageState extends State<ScoreListPage> {
  final ScoreFetchService _fetchService = ScoreFetchService();
  final ScoreStorageService _storageService = ScoreStorageService();
  List<ScoreData> _scores = [];
  bool _isFetching = false;
  bool _isLoading = true;
  int _currentPage = 0;
  DateTime? _lastUpdateTime;
  String _currentDifficulty = '';
  bool _hasFetched = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _loadCachedScores();
  }

  Future<void> _loadCachedScores() async {
    try {
      final scores = await _storageService.loadScores();
      final lastUpdate = await _storageService.getLastUpdateTime();
      
      if (mounted) {
        setState(() {
          _scores = scores;
          _lastUpdateTime = lastUpdate;
          _isLoading = false;
          _hasFetched = scores.isNotEmpty;
        });
      }
    } catch (e) {
      print('加载缓存失败: $e');
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
          _currentPage = response.currentPage;
        });
      }
    });

    _fetchService.errorStream.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    });

    _fetchService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _isFetching = progress >= 0;
        });
      }
    });

    _fetchService.difficultyStream.listen((difficulty) {
      if (mounted) {
        setState(() {
          _currentDifficulty = difficulty;
        });
      }
    });
  }

  @override
  void dispose() {
    _fetchService.dispose();
    super.dispose();
  }

  void _startFetching() {
    setState(() {
      _scores = [];
      _currentPage = 0;
    });
    _fetchService.startFetching().then((_) {
      if (mounted) {
        setState(() {
          _hasFetched = true;
        });
      }
    });
  }

  void _startUpdating() {
    _fetchService.startUpdating().then((_) async {
      // 更新完成后重新加载成绩
      if (mounted) {
        await _loadCachedScores();
      }
    });
  }

  void _stopFetching() {
    _fetchService.stopFetching();
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
          _lastUpdateTime = null;
          _hasFetched = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('缓存已清除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清除失败: $e')),
          );
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
          if (_isFetching)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopFetching,
              tooltip: '停止',
            ),
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
          // 状态栏
          if (_isFetching || _scores.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: _isFetching ? Colors.blue[50] : Colors.green[50],
              child: Row(
                children: [
                  if (_isFetching)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isFetching
                              ? '正在拉取 $_currentDifficulty 难度第 $_currentPage 页...'
                              : '已加载 ${_scores.length} 条成绩',
                          style: TextStyle(
                            color: _isFetching ? Colors.blue[900] : Colors.green[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_lastUpdateTime != null && !_isFetching)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '最后更新: ${_formatDateTime(_lastUpdateTime!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 成绩列表
          Expanded(
            child: _buildScoreList(),
          ),
        ],
      ),
      floatingActionButton: _isFetching
          ? null
          : FloatingActionButton.extended(
              onPressed: _hasFetched ? _startUpdating : _startFetching,
              icon: Icon(_hasFetched ? Icons.refresh : Icons.download),
              label: Text(_hasFetched ? '更新成绩' : '拉取成绩'),
            ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} 小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else {
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    }
  }

  Widget _buildScoreList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_scores.isEmpty && !_isFetching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无成绩数据',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮开始拉取',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _scores.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        return _ScoreCard(score: _scores[index]);
      },
    );
  }
}

/// 成绩卡片组件
class _ScoreCard extends StatelessWidget {
  final ScoreData score;

  const _ScoreCard({required this.score});

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'EX+':
        return Colors.purple[700]!;
      case 'EX':
        return Colors.purple[500]!;
      case 'AA':
        return Colors.pink[600]!;
      case 'A':
        return Colors.blue[600]!;
      case 'B':
        return Colors.green[600]!;
      case 'C':
        return Colors.orange[600]!;
      case 'D':
        return Colors.grey[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'PST':
        return const Color(0xFF4A9C6D); // 绿色
      case 'PRS':
        return const Color(0xFFE8B600); // 黄色
      case 'FTR':
        return const Color(0xFF8B5A9E); // 紫色
      case 'BYD':
        return const Color(0xFFDC143C); // 红色
      default:
        return Colors.grey[600]!;
    }
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
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // 难度标签
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

                  // 日期
                  Text(
                    score.obtainedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
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
}
