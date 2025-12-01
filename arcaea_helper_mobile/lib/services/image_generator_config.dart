import 'dart:ui';

/// 图片生成器配置
/// 移植自 scripts/generate-b30r10-image.js 的 CONFIG 对象
class ImageGeneratorConfig {
  // 画布尺寸
  static const int canvasWidth = 2400;
  static const int canvasHeight = 3900;

  // 顶部玩家信息区域
  static const int headerHeight = 280;
  static const int headerPadding = 40;

  // 卡片布局 (8行5列)
  static const int rows = 8;
  static const int cols = 5;
  static const int cardWidth = 440;
  static const int cardHeight = 420;
  static const int cardMarginX = 20;
  static const int cardMarginY = 20;
  static const int cardsStartY = 300;

  // 颜色方案
  static const Color background = Color(0xFF2D2D3D);
  static const Color headerBg = Color(0x266750A4);
  static const Color cardBg = Color(0xF22D2D41);
  static const Color cardBorder = Color(0x4D6750A4);
  static const Color primary = Color(0xFF667EEA);
  static const Color secondary = Color(0xFF764BA2);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8D1);
  static const Color textTertiary = Color(0xFF8B8B9E);
  static const Color scoreGold = Color(0xFFFFD700);
  static const Color targetScore = Color(0xFF10B981);
  static const Color pttBlue = Color(0xFF60A5FA);

  // 难度颜色
  static const Map<String, Color> difficultyColors = {
    'PST': Color(0xFF0A82BE),
    'PRS': Color(0xFF648C3C),
    'FTR': Color(0xFF501948),
    'BYD': Color(0xFF822328),
    'ETR': Color(0xFF5D4E76),
  };

  // 字体大小
  static const double playerName = 72;
  static const double playerStats = 56;
  static const double playerStatsLabel = 32;
  static const double cardTitle = 48;
  static const double cardScore = 42;
  static const double cardInfo = 36;
  static const double cardDifficulty = 32;
  static const double cardRank = 36;
  static const double cardTarget = 34;
  static const double sectionLabel = 42;
  static const double footer = 24;
}
