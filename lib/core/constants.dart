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
  static const String calculatorScriptPath = 'web/js/arcaea-calculator.js';
  static const String dataLoaderScriptPath = 'web/js/arcaea-data-loader.js';
  static const String contentScriptPath = 'web/js/flutter-content.js';
  static const String stylesPath = 'web/css/arcaea-styles.css';
  static const String chartConstantPath = 'assets/data/ChartConstant.json';
  static const String songlistPath = 'assets/data/Songlist.json';

  // JavaScript Handler名称
  static const String getSharedAssetHandler = 'getSharedAsset';
  static const String exportB30R10DataHandler = 'exportB30R10Data';

  // 注入相关配置
  static const int maxAggressiveAttempts = 150;
  static const Duration aggressiveInterval = Duration(milliseconds: 400);
  static const Duration targetPageGracePeriod = Duration(seconds: 3);
  static const Duration initialDelay = Duration(milliseconds: 800);
  static const Duration domCheckDelay = Duration(milliseconds: 500);
  static const Duration readyCheckInterval = Duration(milliseconds: 100);
  static const int maxReadyCheckAttempts = 20;

  // iOS持续检查延迟配置（毫秒）
  static const List<int> iosContinuousCheckDelays = [
    400, 800, 1200, 1600,      // 前2秒，每400ms
    2000, 2500, 3000,          // 2-3秒
    3500, 4000, 5000,          // 3-5秒
    6000, 7000, 8000,          // 5-8秒
    10000, 12000, 15000, 20000 // 8-20秒
  ];

  // 相册名称
  static const String albumName = 'Arcaea Helper';

  // SharedPreferences键
  static const String prefShowCharts = 'showCharts';
  static const String prefShowConstant = 'showConstant';
  static const String prefShowPTT = 'showPTT';
  static const String prefShowTargetScore = 'showTargetScore';
  static const String prefShowDownloadButtons = 'showDownloadButtons';
}
