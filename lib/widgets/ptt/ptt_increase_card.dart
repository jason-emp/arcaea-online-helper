import 'package:flutter/material.dart';
import '../../core/core.dart';

/// 推分参考卡片
class PTTIncreaseCard extends StatelessWidget {
  final double currentPTT;
  final List<double> best30PTTs;
  final List<double> recent10PTTs;

  const PTTIncreaseCard({
    super.key,
    required this.currentPTT,
    required this.best30PTTs,
    required this.recent10PTTs,
  });

  @override
  Widget build(BuildContext context) {
    final displayedPTT = (currentPTT * 100).floor() / 100;
    final targetPTT = displayedPTT + 0.01;

    final requiredConstants = PTTCalculator.calculateRequiredConstants(
      currentPTT: currentPTT,
      best30PTTs: best30PTTs,
      recent10PTTs: recent10PTTs,
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
            _buildHeader(scheme, displayedPTT, targetPTT),
            const SizedBox(height: 16),
            _buildConstantTable(scheme, requiredConstants),
            const SizedBox(height: 12),
            _buildFooter(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme, double displayedPTT, double targetPTT) {
    return Column(
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
      ],
    );
  }

  Widget _buildConstantTable(ColorScheme scheme, List<Map<String, String>> requiredConstants) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.surfaceContainerHighest.withOpacity(0.6),
        ),
      ),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(
            color: scheme.surfaceContainerHighest.withOpacity(0.5),
            width: 1,
          ),
        ),
        children: [
          // 表头
          TableRow(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.4),
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
                  item['label']!,
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
                  item['constant']!,
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
    );
  }

  Widget _buildFooter(ColorScheme scheme) {
    return Text(
      '※ 基于当前总PTT计算',
      style: TextStyle(
        fontSize: 11,
        fontStyle: FontStyle.italic,
        color: scheme.onTertiaryContainer.withOpacity(0.7),
      ),
    );
  }
}
