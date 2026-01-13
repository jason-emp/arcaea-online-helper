import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/b30r10_data.dart';

/// 玩家信息卡片
class PlayerCard extends StatelessWidget {
  final PlayerData player;
  final double? pttDifference;

  const PlayerCard({
    super.key,
    required this.player,
    this.pttDifference,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfo(scheme),
            const SizedBox(height: 20),
            _buildPTTDisplay(scheme),
            const SizedBox(height: 20),
            _buildStatTiles(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(ColorScheme scheme) {
    return Row(
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
          child: Text(
            player.username,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPTTDisplay(ColorScheme scheme) {
    return Center(
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
            player.totalPTT != null 
                ? player.totalPTT!.toStringAsFixed(4) 
                : '--',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
          if (pttDifference != null) ...[
            const SizedBox(height: 4),
            Text(
              '${pttDifference! >= 0 ? '+' : ''}${pttDifference!.toStringAsFixed(4)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: pttDifference! >= 0 
                    ? ArcaeaColors.positive 
                    : ArcaeaColors.negative,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatTiles(ColorScheme scheme) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        _PlayerStatTile(
          label: 'Best 30 平均',
          value: player.best30Avg,
        ),
        _PlayerStatTile(
          label: 'Recent 10 平均',
          value: player.recent10Avg,
        ),
      ],
    );
  }
}

class _PlayerStatTile extends StatelessWidget {
  final String label;
  final double? value;

  const _PlayerStatTile({
    required this.label,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, 
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value != null ? value!.toStringAsFixed(4) : '--',
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
}
