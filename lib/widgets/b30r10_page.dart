import 'package:flutter/material.dart';
import '../models/b30r10_data.dart';
import '../services/image_generation_manager.dart';
import '../widgets/settings_dialog.dart';

/// B30/R10 Flutter列表页面
class B30R10Page extends StatefulWidget {
  final ImageGenerationManager imageManager;
  final bool isLoggedIn;
  final VoidCallback onNavigateToWebView;
  final VoidCallback onRefreshData;
  final VoidCallback onRefreshWebView;
  // 设置对话框相关回调
  final VoidCallback onGenerateImage;
  final VoidCallback onDownloadLatest;
  final VoidCallback onCheckUpdate;
  final VoidCallback onUpdateData;
  final VoidCallback onClearAllData;
  // 设置对话框状态
  final bool isCheckingUpdate;
  final bool isGeneratingImage;
  final bool isUpdatingData;
  final String? currentVersion;
  final String? latestVersion;
  final String? updateStatusMessage;
  final String? dataUpdateMessage;
  final DateTime? lastDataUpdateTime;

  const B30R10Page({
    super.key,
    required this.imageManager,
    required this.isLoggedIn,
    required this.onNavigateToWebView,
    required this.onRefreshData,
    required this.onRefreshWebView,
    required this.onGenerateImage,
    required this.onDownloadLatest,
    required this.onCheckUpdate,
    required this.onUpdateData,
    required this.onClearAllData,
    required this.isCheckingUpdate,
    required this.isGeneratingImage,
    required this.isUpdatingData,
    this.currentVersion,
    this.latestVersion,
    this.updateStatusMessage,
    this.dataUpdateMessage,
    this.lastDataUpdateTime,
  });

  @override
  State<B30R10Page> createState() => _B30R10PageState();
}

class _B30R10PageState extends State<B30R10Page> {
  B30R10Data? get _data => widget.imageManager.cachedData;
  bool _hasAutoLoaded = false;
  bool _isLoading = false;
  bool _loadFailed = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const int _loadWaitTime = 3000; // 3秒等待时间

  @override
  void initState() {
    super.initState();
    // 启动时总是尝试自动加载数据（无论是否登录）
    if (_data == null && !_hasAutoLoaded) {
      _hasAutoLoaded = true;
      _isLoading = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _refresh();
        }
      });
    }
  }

  @override
  void didUpdateWidget(B30R10Page oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当登录状态变化为已登录，且没有数据时，自动加载
    if (!oldWidget.isLoggedIn &&
        widget.isLoggedIn &&
        _data == null &&
        !_isLoading) {
      _loadFailed = false;
      _retryCount = 0;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _refresh();
        }
      });
    }
  }

  /// 刷新数据（带重试机制）
  Future<void> _refresh() async {
    debugPrint('[B30R10Page] 开始刷新，ImageManager实例: ${widget.imageManager.hashCode}');
    
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    // 监听数据变化
    void dataListener() {
      if (_data != null && mounted) {
        // 数据加载成功
        debugPrint('[B30R10Page] 监听器检测到数据: ${_data!.player.username}');
        widget.imageManager.removeListener(dataListener);
        setState(() {
          _isLoading = false;
          _loadFailed = false;
          _retryCount = 0;
        });
        debugPrint('[B30R10Page] 数据加载成功');
      }
    }
    
    widget.imageManager.addListener(dataListener);

    widget.onRefreshData();

    // 等待数据加载（增加到3秒）
    await Future.delayed(Duration(milliseconds: _loadWaitTime));

    if (mounted) {
      // 移除监听器
      widget.imageManager.removeListener(dataListener);
      
      // 检查是否成功加载数据
      final hasData = _data != null;
      debugPrint('[B30R10Page] 等待结束，检查数据: hasData=$hasData, ImageManager实例: ${widget.imageManager.hashCode}, cachedData=${widget.imageManager.cachedData != null ? widget.imageManager.cachedData!.player.username : "null"}');

      if (!hasData && _retryCount < _maxRetries) {
        // 数据加载失败且还有重试次数
        _retryCount++;
        debugPrint('[B30R10Page] 数据加载失败，尝试第 $_retryCount 次重试...');

        // 等待1秒后重试
        await Future.delayed(const Duration(milliseconds: 1000));

        if (mounted) {
          // 递归调用重试
          await _refresh();
        }
      } else {
        // 达到最大重试次数或加载成功
        setState(() {
          _isLoading = false;
          if (!hasData) {
            // 所有重试都失败
            if (!widget.isLoggedIn) {
              _loadFailed = true;
              debugPrint('[B30R10Page] 数据加载失败: 未登录');
            } else {
              debugPrint('[B30R10Page] 数据加载失败: 已重试 $_retryCount 次');
            }
            _retryCount = 0; // 重置重试计数
          } else {
            debugPrint('[B30R10Page] 数据加载成功');
            _retryCount = 0;
            _loadFailed = false;
          }
        });
      }
    }
  }

  /// 手动重试（重置重试计数）
  Future<void> _manualRetry() async {
    _retryCount = 0;
    await _refresh();
  }

  /// 刷新WebView并重新获取数据
  Future<void> _refreshWebViewAndData() async {
    // 先刷新WebView页面
    widget.onRefreshWebView();

    // 等待WebView刷新完成
    await Future.delayed(const Duration(milliseconds: 1500));

    // 然后重新获取数据
    _retryCount = 0;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在加载，显示加载动画
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('B30/R10'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('正在加载数据...'),
              if (_retryCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '重试中 ($_retryCount/$_maxRetries)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 如果没有数据，显示提示
    if (_data == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('B30/R10'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettingsDialog,
              tooltip: '设置',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _loadFailed ? Icons.login : Icons.download,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _loadFailed ? '请先登录' : '暂无 B30/R10 数据',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                _loadFailed ? '请前往 WebView 页面登录后重试' : '点击下方按钮加载数据',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadFailed
                    ? widget.onNavigateToWebView
                    : _manualRetry,
                icon: Icon(_loadFailed ? Icons.web : Icons.refresh),
                label: Text(_loadFailed ? '前往 WebView 登录' : '重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('B30/R10'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          // 只要有数据就显示生图按钮
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: widget.isGeneratingImage ? null : widget.onGenerateImage,
            tooltip: '生成B30/R10图片',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: '设置',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshWebViewAndData,
            tooltip: '刷新页面并重新获取数据',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildPlayerCard(),
        const SizedBox(height: 16),
        _buildPTTIncreaseCard(),
        const SizedBox(height: 24),
        _buildSongSection(
          title: 'Best 30',
          subtitle: '表现最好的 30 首成绩',
          icon: Icons.star_rounded,
          accentColor: Colors.blue,
          songs: _data!.best30,
          isRecent: false,
        ),
        const SizedBox(height: 24),
        _buildSongSection(
          title: 'Recent 10',
          subtitle: '最新的 10 首成绩',
          icon: Icons.history_rounded,
          accentColor: Colors.orange,
          songs: _data!.recent10,
          isRecent: true,
        ),
      ],
    );
  }

  Widget _buildSongSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<SongCardData> songs,
    required bool isRecent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title, subtitle, icon, accentColor),
        const SizedBox(height: 12),
        ...songs.map((song) => _buildSongCard(song, isRecent)),
      ],
    );
  }

  /// 构建玩家信息卡片
  Widget _buildPlayerCard() {
    final player = _data!.player;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    player.username.isNotEmpty ? player.username[0] : '?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.username,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 总PTT - 独占一行，放大加粗
            Center(
              child: Column(
                children: [
                  Text(
                    '总 PTT',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    player.totalPTT != null ? player.totalPTT!.toStringAsFixed(4) : '--',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Best 30 和 Recent 10 平均
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _buildPlayerStatTile('Best 30 平均', player.best30Avg),
                _buildPlayerStatTile('Recent 10 平均', player.recent10Avg),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStatTile(String label, double? value) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            value != null ? value.toStringAsFixed(4) : '--',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建PTT推分表格卡片
  Widget _buildPTTIncreaseCard() {
    if (_data?.player.totalPTT == null) return const SizedBox.shrink();

    final currentPTT = _data!.player.totalPTT!;
    final displayedPTT = (currentPTT * 100).floor() / 100;
    final targetPTT = displayedPTT + 0.01;

    // 收集所有单曲PTT
    final best30PTTs = _data!.best30
        .where((song) => song.playPTT != null)
        .map((song) => song.playPTT!)
        .toList();
    final recent10PTTs = _data!.recent10
        .where((song) => song.playPTT != null)
        .map((song) => song.playPTT!)
        .toList();

    // 计算所需定数
    final requiredConstants = _calculateRequiredConstants(
      currentPTT,
      best30PTTs,
      recent10PTTs,
    );

    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: scheme.tertiaryContainer.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '推分参考',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '当前显示 ${displayedPTT.toStringAsFixed(2)} → 目标 ${targetPTT.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onTertiaryContainer.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.surfaceVariant.withOpacity(0.6),
                ),
              ),
              child: Table(
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: scheme.surfaceVariant.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                children: [
                  // 表头
                  TableRow(
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    children: requiredConstants.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Text(
                          item['label'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // 数据行
                  TableRow(
                    children: requiredConstants.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Text(
                          item['constant'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '※ 基于当前总PTT计算',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: scheme.onTertiaryContainer.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建分区标题
  Widget _buildSectionHeader(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建歌曲卡片
  Widget _buildSongCard(SongCardData song, bool isRecent) {
    final accentColor = isRecent ? Colors.orange : Colors.blue;
    final prefix = isRecent ? 'R' : '#';
    final targetScore = _calculateTargetScore(song);
    final difficultyColor = _getDifficultyColor(song.difficulty);
    final grade = _getScoreGrade(song.score);
    final gradeColor = _getGradeColor(grade);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: InkWell(
        onTap: () => _showSongDetails(song),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSongCover(song, accentColor, prefix),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.songTitle,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _buildDifficultyChip(
                                        song.difficulty,
                                        difficultyColor,
                                      ),
                                      if (song.constant != null)
                                        Text(
                                          '定数 ${song.constant!.toStringAsFixed(1)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildGradeChip(grade, gradeColor),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '得分',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatScore(song.score),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (song.playPTT != null)
                              _buildInfoPill(
                                label: '单曲 PTT',
                                value: song.playPTT!.toStringAsFixed(4),
                                icon: Icons.data_exploration,
                              ),
                            if (targetScore != null)
                              _buildInfoPill(
                                label: '目标分数',
                                value: _formatScore(targetScore),
                                icon: Icons.flag_outlined,
                                valueColor: Colors.green[600],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongCover(SongCardData song, Color accentColor, String prefix) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: song.coverUrl != null
                  ? Image.network(
                      song.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.music_note,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.music_note, color: Colors.grey[400]),
                    ),
            ),
          ),
          Positioned(
            bottom: -6,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$prefix${song.rank}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip(String difficulty, Color color) {
    return Chip(
      padding: EdgeInsets.zero,
      shape: StadiumBorder(side: BorderSide(color: color.withOpacity(0.6))),
      backgroundColor: color.withOpacity(0.15),
      label: Text(
        difficulty,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildGradeChip(String grade, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        grade,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required String label,
    required String value,
    IconData? icon,
    Color? valueColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'PST':
        return const Color(0xFF4A9C6D);
      case 'PRS':
        return const Color(0xFFE8B600);
      case 'FTR':
        return const Color(0xFF8B5A9E);
      case 'BYD':
        return const Color(0xFFDC143C);
      default:
        return Colors.grey[600]!;
    }
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'PM':
        return Colors.deepPurple[700]!;
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

  String _getScoreGrade(int score) {
    if (score >= 10000000) return 'PM';
    if (score >= 9900000) return 'EX+';
    if (score >= 9800000) return 'EX';
    if (score >= 9500000) return 'AA';
    if (score >= 9200000) return 'A';
    if (score >= 8900000) return 'B';
    if (score >= 8600000) return 'C';
    return 'D';
  }

  /// 显示歌曲详情
  void _showSongDetails(SongCardData song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(song.songTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('难度', song.difficulty),
            _buildDetailRow('分数', _formatScore(song.score)),
            if (song.constant != null)
              _buildDetailRow('定数', song.constant!.toStringAsFixed(1)),
            if (song.playPTT != null)
              _buildDetailRow('PTT', song.playPTT!.toStringAsFixed(4)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  /// 格式化分数
  String _formatScore(int score) {
    return score.toString().padLeft(8, '0');
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 计算目标分数（使PTT +0.01）
  int? _calculateTargetScore(SongCardData song) {
    if (song.constant == null || _data?.player.totalPTT == null) return null;
    if (song.score >= 10000000) return null;

    final constant = song.constant!;
    final totalPTT = _data!.player.totalPTT!;
    final currentDisplayPTT = (totalPTT * 100).floor() / 100;
    final targetDisplayPTT = currentDisplayPTT + 0.01;

    // 计算当前PlayPTT
    double currentPlayPTT;
    if (song.score >= 10000000) {
      currentPlayPTT = constant + 2;
    } else if (song.score >= 9800000) {
      currentPlayPTT = constant + 1 + (song.score - 9800000) / 200000;
    } else {
      currentPlayPTT = constant + (song.score - 9500000) / 300000;
      if (currentPlayPTT < 0) currentPlayPTT = 0;
    }

    // 二分查找目标分数
    int left = song.score + 1;
    int right = 10000000;
    int? result;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      double newPlayPTT;

      if (mid >= 10000000) {
        newPlayPTT = constant + 2;
      } else if (mid >= 9800000) {
        newPlayPTT = constant + 1 + (mid - 9800000) / 200000;
      } else {
        newPlayPTT = constant + (mid - 9500000) / 300000;
        if (newPlayPTT < 0) newPlayPTT = 0;
      }

      final newTotalPTT = totalPTT + (newPlayPTT - currentPlayPTT) / 40;
      final newDisplayPTT = (newTotalPTT * 100).floor() / 100;

      if (newDisplayPTT >= targetDisplayPTT) {
        result = mid;
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    return result;
  }

  /// 计算所需最低谱面定数
  List<Map<String, String>> _calculateRequiredConstants(
    double currentPTT,
    List<double> best30PTTs,
    List<double> recent10PTTs,
  ) {
    final displayedPTT = (currentPTT * 100).floor() / 100;
    final targetPTT = displayedPTT + 0.01;
    final deltaS = 40 * (targetPTT - currentPTT);

    final bMin = best30PTTs.isNotEmpty
        ? best30PTTs.reduce((a, b) => a < b ? a : b)
        : 0.0;
    final rMin = recent10PTTs.isNotEmpty
        ? recent10PTTs.reduce((a, b) => a < b ? a : b)
        : 0.0;

    double xNeeded = double.infinity;

    // 场景A: 仅替换 Recent10
    final xA = rMin + deltaS;
    if (xA <= bMin) {
      xNeeded = xNeeded < xA ? xNeeded : xA;
    }

    // 场景B: 仅替换 Best30
    final xB = bMin + deltaS;
    if (xB <= rMin) {
      xNeeded = xNeeded < xB ? xNeeded : xB;
    }

    // 场景C: 同时替换 Best30 和 Recent10
    final xC = (bMin + rMin + deltaS) / 2;
    if (xC >= bMin && xC >= rMin) {
      xNeeded = xNeeded < xC ? xNeeded : xC;
    }

    if (xNeeded == double.infinity) {
      xNeeded = (bMin > rMin ? bMin : rMin) + deltaS;
    }

    // 不同分数等级
    final scoreGrades = [
      {'label': '995W', 'offset': 1.75},
      {'label': 'EX+', 'offset': 1.5},
      {'label': 'EX', 'offset': 1.0},
      {'label': '970W', 'offset': 0.667},
      {'label': '960W', 'offset': 0.333},
      {'label': 'AA', 'offset': 0.0},
    ];

    return scoreGrades.map((grade) {
      final rawConstant = xNeeded - (grade['offset'] as double);
      final constant = (rawConstant * 10).ceil() / 10;
      return {
        'label': grade['label'] as String,
        'constant': constant.toStringAsFixed(1),
      };
    }).toList();
  }

  /// 显示设置对话框
  void _showSettingsDialog() {
    showSettingsDialog(
      context: context,
      onGenerateImage: widget.onGenerateImage,
      onDownloadLatest: widget.onDownloadLatest,
      onCheckUpdate: widget.onCheckUpdate,
      onUpdateData: widget.onUpdateData,
      onClearAllData: widget.onClearAllData,
      isCheckingUpdate: widget.isCheckingUpdate,
      isGeneratingImage: widget.isGeneratingImage,
      isUpdatingData: widget.isUpdatingData,
      canGenerateImage: widget.isLoggedIn,
      currentVersion: widget.currentVersion,
      latestVersion: widget.latestVersion,
      updateStatusMessage: widget.updateStatusMessage,
      dataUpdateMessage: widget.dataUpdateMessage,
      lastDataUpdateTime: widget.lastDataUpdateTime,
    );
  }
}
