import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/score_data.dart';
import '../common/arcaea_widgets.dart';

/// 成绩卡片组件
class ScoreCard extends StatelessWidget {
  final ScoreData score;
  final double? constant;
  final double? playPTT;
  final int? targetScore;
  final String? targetSource;

  const ScoreCard({
    super.key,
    required this.score,
    this.constant,
    this.playPTT,
    this.targetScore,
    this.targetSource,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCover(),
            const SizedBox(width: 12),
            Expanded(child: _buildInfo(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildCover() {
    return ClipRRect(
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
    );
  }

  Widget _buildInfo(BuildContext context) {
    final gradeColor = ArcaeaColors.getGradeColor(score.grade);

    return Column(
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
            DifficultyChip(difficulty: score.difficulty, dense: true),
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

        // PTT 和目标分数
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
                  value: Formatters.formatScoreWithCommas(targetScore!),
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
    final chipColor = scheme.surfaceContainerHighest.withOpacity(0.7);
    
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
}
