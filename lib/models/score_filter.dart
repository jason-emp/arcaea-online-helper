/// 成绩筛选条件
class ScoreFilter {
  /// 难度筛选（可多选）
  final Set<String> difficulties;
  
  /// 曲包筛选（可多选）
  final Set<String> packs;
  
  /// 谱面定数上限
  final double? constantMax;
  
  /// 谱面定数下限
  final double? constantMin;
  
  /// 单曲PTT上限
  final double? pttMax;
  
  /// 单曲PTT下限
  final double? pttMin;
  
  /// 成绩上限
  final int? scoreMax;
  
  /// 成绩下限
  final int? scoreMin;
  
  /// 目标上限
  final int? targetMax;
  
  /// 目标下限
  final int? targetMin;
  
  /// 是否仅显示有目标的曲目
  final bool onlyWithTarget;

  const ScoreFilter({
    this.difficulties = const {},
    this.packs = const {},
    this.constantMax,
    this.constantMin,
    this.pttMax,
    this.pttMin,
    this.scoreMax,
    this.scoreMin,
    this.targetMax,
    this.targetMin,
    this.onlyWithTarget = false,
  });

  /// 是否有任何筛选条件
  bool get hasAnyFilter {
    return difficulties.isNotEmpty ||
        packs.isNotEmpty ||
        constantMax != null ||
        constantMin != null ||
        pttMax != null ||
        pttMin != null ||
        scoreMax != null ||
        scoreMin != null ||
        targetMax != null ||
        targetMin != null ||
        onlyWithTarget;
  }

  /// 清除所有筛选条件
  ScoreFilter clear() {
    return const ScoreFilter();
  }

  /// 复制并修改筛选条件
  ScoreFilter copyWith({
    Set<String>? difficulties,
    Set<String>? packs,
    double? Function()? constantMax,
    double? Function()? constantMin,
    double? Function()? pttMax,
    double? Function()? pttMin,
    int? Function()? scoreMax,
    int? Function()? scoreMin,
    int? Function()? targetMax,
    int? Function()? targetMin,
    bool? onlyWithTarget,
  }) {
    return ScoreFilter(
      difficulties: difficulties ?? this.difficulties,
      packs: packs ?? this.packs,
      constantMax: constantMax != null ? constantMax() : this.constantMax,
      constantMin: constantMin != null ? constantMin() : this.constantMin,
      pttMax: pttMax != null ? pttMax() : this.pttMax,
      pttMin: pttMin != null ? pttMin() : this.pttMin,
      scoreMax: scoreMax != null ? scoreMax() : this.scoreMax,
      scoreMin: scoreMin != null ? scoreMin() : this.scoreMin,
      targetMax: targetMax != null ? targetMax() : this.targetMax,
      targetMin: targetMin != null ? targetMin() : this.targetMin,
      onlyWithTarget: onlyWithTarget ?? this.onlyWithTarget,
    );
  }

  /// 预设的成绩值
  static const Map<String, int> scorePresets = {
    'PM': 10000000,
    'EX+': 9900000,
    'EX': 9800000,
    'AA': 9500000,
    'A': 9200000,
  };

  /// 获取活跃的筛选条件描述
  List<String> getActiveFilterDescriptions() {
    final List<String> descriptions = [];

    if (difficulties.isNotEmpty) {
      descriptions.add('难度: ${difficulties.join(", ")}');
    }

    if (packs.isNotEmpty) {
      if (packs.length <= 3) {
        descriptions.add('曲包: ${packs.join(", ")}');
      } else {
        descriptions.add('曲包: ${packs.length} 个');
      }
    }

    if (constantMin != null || constantMax != null) {
      if (constantMin != null && constantMax != null) {
        descriptions.add('定数: ${constantMin!.toStringAsFixed(1)} - ${constantMax!.toStringAsFixed(1)}');
      } else if (constantMin != null) {
        descriptions.add('定数 ≥ ${constantMin!.toStringAsFixed(1)}');
      } else {
        descriptions.add('定数 ≤ ${constantMax!.toStringAsFixed(1)}');
      }
    }

    if (pttMin != null || pttMax != null) {
      if (pttMin != null && pttMax != null) {
        descriptions.add('PTT: ${pttMin!.toStringAsFixed(2)} - ${pttMax!.toStringAsFixed(2)}');
      } else if (pttMin != null) {
        descriptions.add('PTT ≥ ${pttMin!.toStringAsFixed(2)}');
      } else {
        descriptions.add('PTT ≤ ${pttMax!.toStringAsFixed(2)}');
      }
    }

    if (scoreMin != null || scoreMax != null) {
      if (scoreMin != null && scoreMax != null) {
        descriptions.add('成绩: ${_formatScore(scoreMin!)} - ${_formatScore(scoreMax!)}');
      } else if (scoreMin != null) {
        descriptions.add('成绩 ≥ ${_formatScore(scoreMin!)}');
      } else {
        descriptions.add('成绩 ≤ ${_formatScore(scoreMax!)}');
      }
    }

    if (targetMin != null || targetMax != null || onlyWithTarget) {
      if (onlyWithTarget) {
        descriptions.add('仅显示有目标');
      }
      if (targetMin != null || targetMax != null) {
        if (targetMin != null && targetMax != null) {
          descriptions.add('目标: ${_formatScore(targetMin!)} - ${_formatScore(targetMax!)}');
        } else if (targetMin != null) {
          descriptions.add('目标 ≥ ${_formatScore(targetMin!)}');
        } else {
          descriptions.add('目标 ≤ ${_formatScore(targetMax!)}');
        }
      }
    }

    return descriptions;
  }

  static String _formatScore(int score) {
    final scoreStr = score.toString().padLeft(8, '0');
    return '${scoreStr.substring(0, 2)},${scoreStr.substring(2, 5)},${scoreStr.substring(5)}';
  }
}
