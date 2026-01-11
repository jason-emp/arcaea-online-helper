import 'package:flutter/material.dart';

/// Arcaea 主题颜色定义
/// 集中管理所有难度、评级等相关的颜色
class ArcaeaColors {
  ArcaeaColors._();

  // ========== 难度颜色 ==========
  
  /// Past 难度颜色 (绿色)
  static const Color difficultyPast = Color(0xFF4A9C6D);
  
  /// Present 难度颜色 (黄色)
  static const Color difficultyPresent = Color(0xFFE8B600);
  
  /// Future 难度颜色 (紫色)
  static const Color difficultyFuture = Color(0xFF8B5A9E);
  
  /// Beyond 难度颜色 (红色)
  static const Color difficultyBeyond = Color(0xFFDC143C);
  
  /// Eternal 难度颜色 (深紫)
  static const Color difficultyEternal = Color(0xFF6A0DAD);

  /// 根据难度名称获取颜色
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'PST':
      case 'PAST':
        return difficultyPast;
      case 'PRS':
      case 'PRESENT':
        return difficultyPresent;
      case 'FTR':
      case 'FUTURE':
        return difficultyFuture;
      case 'BYD':
      case 'BEYOND':
        return difficultyBeyond;
      case 'ETR':
      case 'ETERNAL':
        return difficultyEternal;
      default:
        return Colors.grey;
    }
  }

  // ========== 评级颜色 ==========
  
  static const Color gradePM = Color(0xFF512DA8);    // 深紫
  static const Color gradeEXPlus = Color(0xFF7B1FA2); // 紫
  static const Color gradeEX = Color(0xFF9C27B0);     // 浅紫
  static const Color gradeAA = Color(0xFFD81B60);     // 粉红
  static const Color gradeA = Color(0xFF1976D2);      // 蓝
  static const Color gradeB = Color(0xFF388E3C);      // 绿
  static const Color gradeC = Color(0xFFF57C00);      // 橙
  static const Color gradeD = Color(0xFF757575);      // 灰

  /// 根据评级获取颜色
  static Color getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'PM':
        return gradePM;
      case 'EX+':
        return gradeEXPlus;
      case 'EX':
        return gradeEX;
      case 'AA':
        return gradeAA;
      case 'A':
        return gradeA;
      case 'B':
        return gradeB;
      case 'C':
        return gradeC;
      case 'D':
      default:
        return gradeD;
    }
  }

  /// 根据分数获取评级
  static String getScoreGrade(int score) {
    if (score >= 10000000) return 'PM';
    if (score >= 9900000) return 'EX+';
    if (score >= 9800000) return 'EX';
    if (score >= 9500000) return 'AA';
    if (score >= 9200000) return 'A';
    if (score >= 8900000) return 'B';
    if (score >= 8600000) return 'C';
    return 'D';
  }

  // ========== 应用主题色 ==========
  
  /// 主色调
  static const Color primary = Color(0xFF667EEA);
  
  /// 金色（用于 PTT 显示）
  static const Color gold = Color(0xFFFFD700);
  
  /// 正向变化（PTT 上升）
  static const Color positive = Color(0xFF4CAF50);
  
  /// 负向变化（PTT 下降）
  static const Color negative = Color(0xFFF44336);

  // ========== B30/R10 区域颜色 ==========
  
  /// Best 30 主色
  static const Color best30Accent = Colors.blue;
  
  /// Recent 10 主色
  static const Color recent10Accent = Colors.orange;
}
