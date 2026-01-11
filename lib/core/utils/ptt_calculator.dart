/// PTT 计算工具类
/// 集中所有与 Arcaea PTT 计算相关的逻辑
class PTTCalculator {
  PTTCalculator._();

  /// 根据分数和定数计算单曲 PTT
  /// 
  /// 计算规则:
  /// - score >= 10,000,000: PTT = constant + 2
  /// - score >= 9,800,000: PTT = constant + 1 + (score - 9,800,000) / 200,000
  /// - score >= 9,500,000: PTT = constant + (score - 9,500,000) / 300,000
  /// - score < 9,500,000: PTT = max(0, constant + (score - 9,500,000) / 300,000)
  static double? calculatePlayPTT(int score, double? constant) {
    if (constant == null) return null;
    
    if (score >= 10000000) {
      return constant + 2;
    } else if (score >= 9800000) {
      return constant + 1 + (score - 9800000) / 200000;
    } else {
      final ptt = constant + (score - 9500000) / 300000;
      return ptt < 0 ? 0 : ptt;
    }
  }

  /// 计算目标分数（使显示 PTT +0.01）
  /// 
  /// 使用二分查找找到能使显示 PTT 增加 0.01 的最小分数
  /// 返回 null 表示无法达成目标（如当前分数已满分）
  static int? calculateTargetScore({
    required double constant,
    required int currentScore,
    required double totalPTT,
  }) {
    if (currentScore >= 10000000) return null;

    final currentDisplayPTT = (totalPTT * 100).floor() / 100;
    final targetDisplayPTT = currentDisplayPTT + 0.01;

    final currentPlayPTT = calculatePlayPTT(currentScore, constant);
    if (currentPlayPTT == null) return null;

    int left = currentScore + 1;
    int right = 10000000;
    int? result;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final newPlayPTT = calculatePlayPTT(mid, constant);
      if (newPlayPTT == null) {
        left = mid + 1;
        continue;
      }

      final newTotalPTT = totalPTT - currentPlayPTT / 40 + newPlayPTT / 40;
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

  /// 计算替代 B30/R10 后的目标分数
  /// 
  /// 当成绩不在当前 B30/R10 中时，计算需要多少分才能替换掉最低的成绩并使 PTT +0.01
  static int? calculateReplacementTargetScore({
    required double constant,
    required int currentScore,
    required double totalPTT,
    required double replacedPTT,
  }) {
    final displayPTT = (totalPTT * 100).floor() / 100;
    final targetDisplay = displayPTT + 0.01;
    final maxPotential = constant + 2;
    
    // 如果该曲目最高可能的 PTT 都无法超过被替换的 PTT，则无法达成目标
    if (maxPotential <= replacedPTT + 1e-9) {
      return null;
    }

    int left = currentScore >= 10000000 ? 10000000 : currentScore + 1;
    if (left > 10000000) return null;
    int right = 10000000;
    int? result;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final newPlayPTT = calculatePlayPTT(mid, constant);
      if (newPlayPTT == null) {
        left = mid + 1;
        continue;
      }

      double newTotalPTT;
      if (newPlayPTT <= replacedPTT + 1e-9) {
        // 新成绩的 PTT 不足以替换现有成绩
        newTotalPTT = totalPTT;
      } else {
        // 替换后的新总 PTT
        newTotalPTT = totalPTT - replacedPTT / 40 + newPlayPTT / 40;
      }
      final newDisplay = (newTotalPTT * 100).floor() / 100;

      if (newDisplay >= targetDisplay) {
        result = mid;
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    if (result == null) return null;
    
    // 验证结果
    final achievedPTT = calculatePlayPTT(result, constant);
    if (achievedPTT == null || achievedPTT <= replacedPTT + 1e-9) return null;
    
    final finalTotal = totalPTT - replacedPTT / 40 + achievedPTT / 40;
    final finalDisplay = (finalTotal * 100).floor() / 100;
    return finalDisplay >= targetDisplay ? result : null;
  }

  /// 计算推分所需的谱面定数
  /// 
  /// 返回不同分数等级（995W、EX+、EX、970W、960W、AA）所需的最低定数
  static List<Map<String, String>> calculateRequiredConstants({
    required double currentPTT,
    required List<double> best30PTTs,
    required List<double> recent10PTTs,
  }) {
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

    // 不同分数等级对应的 PTT 偏移量
    const scoreGrades = [
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
}
