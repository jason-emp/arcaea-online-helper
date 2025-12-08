import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

/// 应用设置模型
class AppSettings {
  bool showCharts;
  bool showConstant;
  bool showPTT;
  bool showTargetScore;
  bool showDownloadButtons;

  AppSettings({
    this.showCharts = false,
    this.showConstant = true,
    this.showPTT = true,
    this.showTargetScore = true,
    this.showDownloadButtons = true,
  });

  /// 从SharedPreferences加载设置
  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppSettings(
        showCharts: prefs.getBool(AppConstants.prefShowCharts) ?? false,
        showConstant: prefs.getBool(AppConstants.prefShowConstant) ?? true,
        showPTT: prefs.getBool(AppConstants.prefShowPTT) ?? true,
        showTargetScore: prefs.getBool(AppConstants.prefShowTargetScore) ?? true,
        showDownloadButtons: prefs.getBool(AppConstants.prefShowDownloadButtons) ?? true,
      );
    } catch (e) {
      return AppSettings();
    }
  }

  /// 保存设置到SharedPreferences
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefShowCharts, showCharts);
      await prefs.setBool(AppConstants.prefShowConstant, showConstant);
      await prefs.setBool(AppConstants.prefShowPTT, showPTT);
      await prefs.setBool(AppConstants.prefShowTargetScore, showTargetScore);
      await prefs.setBool(AppConstants.prefShowDownloadButtons, showDownloadButtons);
    } catch (e) {
      rethrow;
    }
  }

  /// 转换为JavaScript对象字符串
  String toJavaScriptObject() {
    return '''
      {
        showCharts: $showCharts,
        showConstant: $showConstant,
        showPTT: $showPTT,
        showTargetScore: $showTargetScore,
        showDownloadButtons: $showDownloadButtons,
      }
    ''';
  }

  AppSettings copyWith({
    bool? showCharts,
    bool? showConstant,
    bool? showPTT,
    bool? showTargetScore,
    bool? showDownloadButtons,
  }) {
    return AppSettings(
      showCharts: showCharts ?? this.showCharts,
      showConstant: showConstant ?? this.showConstant,
      showPTT: showPTT ?? this.showPTT,
      showTargetScore: showTargetScore ?? this.showTargetScore,
      showDownloadButtons: showDownloadButtons ?? this.showDownloadButtons,
    );
  }
}
