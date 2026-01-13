import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/app_settings.dart';
import '../models/b30r10_data.dart';
import '../models/score_data.dart';
import '../services/image_generation_manager.dart';
import '../services/score_storage_service.dart';
import '../services/song_data_service.dart';

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
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

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
    required this.settings,
    required this.onSettingsChanged,
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
  final ScoreStorageService _storageService = ScoreStorageService();
  final SongDataService _songDataService = SongDataService();
  double? _pttDifference; // PTT差值
  List<SongCardData> _extraBestSongs = [];
  bool _isLoadingExtraSongs = false;
  String? _extraSongsMessage;

  @override
  void initState() {
    super.initState();
    // 启动时总是尝试自动加载数据（无论是否登录）
    if (_data == null && !_hasAutoLoaded) {
      _hasAutoLoaded = true;
      _isLoading = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          // 启动时也先刷新WebView页面,确保获取最新数据
          _refreshWebViewAndData();
        }
      });
    }

    if (_data != null && widget.settings.extraBestSongsCount > 0) {
      _loadExtraBestSongs();
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
          // 登录后也先刷新页面再获取数据
          _refreshWebViewAndData();
        }
      });
    }

    if (oldWidget.settings.extraBestSongsCount !=
        widget.settings.extraBestSongsCount) {
      _loadExtraBestSongs();
    }
  }

  /// 刷新数据（带重试机制）
  Future<void> _refresh() async {
    // 在开始刷新前，保存当前PTT作为上一次的PTT
    final currentPTT = _data?.player.totalPTT;
    if (currentPTT != null) {
      await _storageService.savePreviousPTT(currentPTT);
    }

    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    // 监听数据变化
    void dataListener() {
      if (_data != null && mounted) {
        // 数据加载成功，对比PTT变化
        _comparePTT();
        _loadExtraBestSongs();
        widget.imageManager.removeListener(dataListener);
        setState(() {
          _isLoading = false;
          _loadFailed = false;
          _retryCount = 0;
        });
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

      if (!hasData && _retryCount < _maxRetries) {
        // 数据加载失败且还有重试次数
        _retryCount++;

        // 等待1秒后重试
        await Future.delayed(const Duration(milliseconds: 1000));

        if (mounted) {
          // 递归调用重试
          await _refresh();
        }
      } else {
        // 达到最大重试次数或加载成功
        if (hasData) {
          // 对比PTT变化
          await _comparePTT();
          _loadExtraBestSongs();
        }
        setState(() {
          _isLoading = false;
          if (!hasData) {
            // 所有重试都失败
            if (!widget.isLoggedIn) {
              _loadFailed = true;
            }
            _retryCount = 0; // 重置重试计数
          } else {
            _retryCount = 0;
            _loadFailed = false;
          }
        });
      }
    }
  }

  /// 对比PTT变化
  Future<void> _comparePTT() async {
    final currentPTT = _data?.player.totalPTT;
    if (currentPTT == null) {
      setState(() {
        _pttDifference = null;
      });
      return;
    }

    final previousPTT = await _storageService.getPreviousPTT();
    if (previousPTT == null) {
      // 第一次加载，没有上一次的PTT
      setState(() {
        _pttDifference = null;
      });
      return;
    }

    final difference = currentPTT - previousPTT;
    // 只有当差值不为0时才显示
    if (difference.abs() < 0.0001) {
      // 差值太小，视为没有变化
      setState(() {
        _pttDifference = null;
      });
    } else {
      setState(() {
        _pttDifference = difference;
      });
    }
  }

  Future<void> _loadExtraBestSongs() async {
    final data = _data;
    final extraCount = widget.settings.extraBestSongsCount;

    if (data == null || extraCount <= 0) {
      if (_extraBestSongs.isNotEmpty || _extraSongsMessage != null) {
        if (mounted) {
          setState(() {
            _extraBestSongs = [];
            _extraSongsMessage = null;
            _isLoadingExtraSongs = false;
          });
        } else {
          _extraBestSongs = [];
          _extraSongsMessage = null;
          _isLoadingExtraSongs = false;
        }
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingExtraSongs = true;
        _extraSongsMessage = null;
      });
    } else {
      _isLoadingExtraSongs = true;
      _extraSongsMessage = null;
    }

    try {
      final scores = await _storageService.loadScores();
      if (!mounted) return;

      if (scores.isEmpty) {
        setState(() {
          _extraBestSongs = [];
          _extraSongsMessage = '需要先在成绩列表页拉取成绩';
          _isLoadingExtraSongs = false;
        });
        return;
      }

      await _songDataService.ensureLoaded();
      final extras = _buildExtraSongsFromScores(scores, data, extraCount);

      if (!mounted) return;
      setState(() {
        _extraBestSongs = extras;
        if (extras.isEmpty) {
          _extraSongsMessage = '没有找到更多的高分成绩';
        } else if (extras.length < extraCount) {
          _extraSongsMessage = '仅找到 ${extras.length} 首符合条件的曲目';
        } else {
          _extraSongsMessage = null;
        }
        _isLoadingExtraSongs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _extraBestSongs = [];
        _extraSongsMessage = '加载额外曲目失败';
        _isLoadingExtraSongs = false;
      });
    }
  }

  List<SongCardData> _buildExtraSongsFromScores(
    List<ScoreData> scores,
    B30R10Data data,
    int extraCount,
  ) {
    final Map<String, SongCardData> knownSongs = {};
    for (final song in data.best30) {
      knownSongs[_buildSongKey(song.songTitle, song.difficulty)] = song;
    }
    for (final song in data.recent10) {
      final key = _buildSongKey(song.songTitle, song.difficulty);
      knownSongs.putIfAbsent(key, () => song);
    }

    final Set<String> excludedKeys = data.best30
        .map((song) => _buildSongKey(song.songTitle, song.difficulty))
        .toSet();

    final List<_ExtraSongCandidate> candidates = [];
    for (final score in scores) {
      final key = _buildSongKey(score.songTitle, score.difficulty);
      if (excludedKeys.contains(key)) continue;

      final reference = knownSongs[key];
      final constant = reference?.constant ??
          _songDataService.getConstant(score.songTitle, score.difficulty);
      if (constant == null) continue;

      final playPTT =
          reference?.playPTT ?? _calculatePlayPTT(score.score, constant);
      if (playPTT == null) continue;

      candidates.add(
        _ExtraSongCandidate(
          score: score,
          constant: constant,
          playPTT: playPTT,
        ),
      );
    }

    candidates.sort((a, b) => b.playPTT.compareTo(a.playPTT));
    final selected = candidates.take(extraCount).toList();

    final extras = <SongCardData>[];
    var rank = data.best30.length + 1;

    for (final candidate in selected) {
      extras.add(
        SongCardData(
          songTitle: candidate.score.songTitle,
          difficulty: candidate.score.difficulty.toUpperCase(),
          difficultyIndex: _parseDifficultyIndex(candidate.score.difficulty),
          score: candidate.score.score,
          constant: candidate.constant,
          playPTT: candidate.playPTT,
          coverUrl: candidate.score.albumArtUrl,
          rank: rank++,
        ),
      );
    }

    return extras;
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
        if (widget.settings.extraBestSongsCount > 0) ...[
          const SizedBox(height: 16),
          _buildExtraBestSongsSection(),
        ],
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

  Widget _buildExtraBestSongsSection() {
    final requested = widget.settings.extraBestSongsCount;
    final effectiveCount = _extraBestSongs.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDashedDivider(),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '追加曲目',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              requested > 0 ? '+$requested' : '关闭',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const Spacer(),
            IconButton(
              onPressed: _isLoadingExtraSongs ? null : _loadExtraBestSongs,
              tooltip: '重新加载追加曲目',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Text(
          effectiveCount > 0
              ? '已追加 $effectiveCount 首曲目'
              : '根据成绩列表缓存追加显示',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        if (_isLoadingExtraSongs)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_extraBestSongs.isNotEmpty)
          ..._extraBestSongs.map((song) => _buildSongCard(song, false))
        else if (_extraSongsMessage != null)
          _buildInfoBanner(_extraSongsMessage!),
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
                  // 显示PTT变化
                  if (_pttDifference != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_pttDifference! >= 0 ? '+' : ''}${_pttDifference!.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _pttDifference! >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
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

  Widget _buildDashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        final rawCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        final dashCount = rawCount <= 0 ? 1 : rawCount;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (index) {
            return Container(
              width: dashWidth,
              height: 1,
              color: Colors.grey[400],
            );
          }),
        );
      },
    );
  }

  Widget _buildInfoBanner(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
    return ArcaeaColors.getDifficultyColor(difficulty);
  }

  Color _getGradeColor(String grade) {
    return ArcaeaColors.getGradeColor(grade);
  }

  String _getScoreGrade(int score) {
    return Formatters.getScoreGrade(score);
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
    return Formatters.formatScore(score);
  }

  /// 计算目标分数（使PTT +0.01）
  int? _calculateTargetScore(SongCardData song) {
    if (song.constant == null || _data?.player.totalPTT == null) return null;
    if (song.score >= 10000000) return null;
    return PTTCalculator.calculateTargetScore(
      constant: song.constant!,
      currentScore: song.score,
      totalPTT: _data!.player.totalPTT!,
    );
  }

  /// 计算所需最低谱面定数
  List<Map<String, String>> _calculateRequiredConstants(
    double currentPTT,
    List<double> best30PTTs,
    List<double> recent10PTTs,
  ) {
    return PTTCalculator.calculateRequiredConstants(
      currentPTT: currentPTT,
      best30PTTs: best30PTTs,
      recent10PTTs: recent10PTTs,
    );
  }

  double? _calculatePlayPTT(int score, double constant) {
    return PTTCalculator.calculatePlayPTT(score, constant);
  }

  int _parseDifficultyIndex(String difficulty) {
    final idx = DifficultyUtils.parseDifficultyIndex(difficulty);
    return idx >= 0 ? idx : 0;
  }

  String _buildSongKey(String title, String difficulty) {
    return '${title.trim().toLowerCase()}|${difficulty.trim().toUpperCase()}';
  }
}

class _ExtraSongCandidate {
  final ScoreData score;
  final double constant;
  final double playPTT;

  _ExtraSongCandidate({
    required this.score,
    required this.constant,
    required this.playPTT,
  });
}
