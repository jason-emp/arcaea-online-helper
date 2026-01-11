import 'package:flutter/material.dart';
import '../../core/theme/arcaea_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/b30r10_data.dart';
import '../common/arcaea_widgets.dart';

/// 歌曲卡片组件
class SongCard extends StatelessWidget {
  final SongCardData song;
  final bool isRecent;
  final int? targetScore;
  final VoidCallback? onTap;

  const SongCard({
    super.key,
    required this.song,
    this.isRecent = false,
    this.targetScore,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isRecent 
        ? ArcaeaColors.recent10Accent 
        : ArcaeaColors.best30Accent;
    final prefix = isRecent ? 'R' : '#';
    final grade = ArcaeaColors.getScoreGrade(song.score);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SongCover(
                coverUrl: song.coverUrl,
                size: 84,
                borderRadius: 16,
                badge: RankBadge(
                  rank: song.rank,
                  color: accentColor,
                  prefix: prefix,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildSongInfo(context, grade)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo(BuildContext context, String grade) {
    return Column(
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
                      DifficultyChip(difficulty: song.difficulty),
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
            GradeChip(grade: grade, large: true),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '得分',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          Formatters.formatScore(song.score),
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
              InfoPill(
                label: '单曲 PTT',
                value: song.playPTT!.toStringAsFixed(4),
                icon: Icons.data_exploration,
              ),
            if (targetScore != null)
              InfoPill(
                label: '目标分数',
                value: Formatters.formatScore(targetScore!),
                icon: Icons.flag_outlined,
                valueColor: Colors.green[600],
              ),
          ],
        ),
      ],
    );
  }
}

/// 歌曲区段标题
class SongSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const SongSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// 歌曲详情对话框
void showSongDetailDialog(BuildContext context, SongCardData song) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(song.songTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(label: '难度', value: song.difficulty),
          _DetailRow(
            label: '分数', 
            value: Formatters.formatScore(song.score),
          ),
          if (song.constant != null)
            _DetailRow(
              label: '定数', 
              value: song.constant!.toStringAsFixed(1),
            ),
          if (song.playPTT != null)
            _DetailRow(
              label: 'PTT', 
              value: song.playPTT!.toStringAsFixed(4),
            ),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
}
