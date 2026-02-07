/// 应用常量定义
class AppConstants {
  AppConstants._();

  // URL相关
  static const String arcaeaHost = 'arcaea.lowiro.com';
  static const String profilePotentialPath = '/profile/potential';
  static const String initialUrl = 'https://arcaea.lowiro.com/zh/profile/potential';
  static const String githubReleaseUrl = 'https://github.com/jason-emp/arcaea-online-helper/releases/latest';
  static const String githubApiUrl = 'https://api.github.com/repos/jason-emp/arcaea-online-helper/releases/latest';

  // 资源路径
  static const String chartConstantPath = 'assets/data/ChartConstant.json';
  static const String songlistPath = 'assets/data/Songlist.json';

  // 数据提取相关配置
  static const Duration targetPageGracePeriod = Duration(seconds: 3);
  static const Duration initialDelay = Duration(milliseconds: 800);
  static const Duration domCheckDelay = Duration(milliseconds: 500);

  // 相册名称
  static const String albumName = 'Arcaea Helper';

  // SharedPreferences键
  static const String prefShowCharts = 'showCharts';
  static const String prefShowConstant = 'showConstant';
  static const String prefShowPTT = 'showPTT';
  static const String prefShowTargetScore = 'showTargetScore';
  static const String prefShowDownloadButtons = 'showDownloadButtons';
  static const String prefExtraBestSongsCount = 'extraBestSongsCount';
  static const String prefSelectedPartnerIconUrl = 'selectedPartnerIconUrl';
  static const String prefHasShownUpgradeNotice = 'hasShownUpgradeNotice_v1_2_0';
}
