import 'package:flutter/material.dart';
import '../../core/core.dart';

/// 难度标签组件
class DifficultyChip extends StatelessWidget {
  final String difficulty;
  final bool dense;

  const DifficultyChip({
    super.key,
    required this.difficulty,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = ArcaeaColors.getDifficultyColor(difficulty);
    
    if (dense) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          difficulty,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }
    
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
}

/// 评级标签组件
class GradeChip extends StatelessWidget {
  final String grade;
  final bool large;

  const GradeChip({
    super.key,
    required this.grade,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = ArcaeaColors.getGradeColor(grade);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(large ? 12 : 4),
      ),
      child: Text(
        grade,
        style: TextStyle(
          color: Colors.white,
          fontSize: large ? 12 : 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 信息胶囊组件
/// 用于显示定数、PTT、目标分数等信息
class InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  const InfoPill({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
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
}

/// 歌曲封面组件
class SongCover extends StatelessWidget {
  final String? coverUrl;
  final double size;
  final double borderRadius;
  final Widget? badge;

  const SongCover({
    super.key,
    this.coverUrl,
    this.size = 80,
    this.borderRadius = 8,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: coverUrl != null && coverUrl!.isNotEmpty
                ? Image.network(
                    coverUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholder();
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildLoadingPlaceholder();
                    },
                  )
                : _buildPlaceholder(),
          ),
          if (badge != null)
            Positioned(
              bottom: -6,
              left: 0,
              child: badge!,
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[200],
      child: Icon(
        Icons.music_note,
        size: size * 0.5,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: SizedBox(
        width: size * 0.25,
        height: size * 0.25,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

/// 排名徽章组件
class RankBadge extends StatelessWidget {
  final int rank;
  final Color color;
  final String prefix;

  const RankBadge({
    super.key,
    required this.rank,
    required this.color,
    this.prefix = '#',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$prefix$rank',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// 空状态组件
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}

/// 虚线分隔符
class DashedDivider extends StatelessWidget {
  final double dashWidth;
  final double dashSpace;
  final Color? color;

  const DashedDivider({
    super.key,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rawCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        final dashCount = rawCount <= 0 ? 1 : rawCount;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (index) {
            return Container(
              width: dashWidth,
              height: 1,
              color: color ?? Colors.grey[400],
            );
          }),
        );
      },
    );
  }
}
