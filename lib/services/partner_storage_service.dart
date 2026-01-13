import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/partner_data.dart';

/// 搭档存储服务
/// 负责搭档数据的本地持久化
class PartnerStorageService {
  static const String _partnersKey = 'cached_partners';
  static const String _lastUpdateKey = 'partners_last_update';

  /// 保存搭档列表
  Future<void> savePartners(List<PartnerData> partners) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 将搭档列表转换为JSON
      final partnersJson = partners.map((p) => p.toJson()).toList();
      final jsonString = jsonEncode(partnersJson);

      // 保存到SharedPreferences
      await prefs.setString(_partnersKey, jsonString);
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());

      print('[搭档存储] 已保存 ${partners.length} 个搭档');
    } catch (e) {
      print('[搭档存储] 保存失败: $e');
      rethrow;
    }
  }

  /// 加载搭档列表
  Future<List<PartnerData>> loadPartners() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_partnersKey);

      if (jsonString == null || jsonString.isEmpty) {
        print('[搭档存储] 无缓存数据');
        return [];
      }

      // 解析JSON
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final partners =
          jsonList.map((json) => PartnerData.fromJson(json)).toList();

      print('[搭档存储] 已加载 ${partners.length} 个搭档');
      return partners;
    } catch (e) {
      print('[搭档存储] 加载失败: $e');
      return [];
    }
  }

  /// 获取最后更新时间
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString(_lastUpdateKey);

      if (timeString == null) {
        return null;
      }

      return DateTime.parse(timeString);
    } catch (e) {
      return null;
    }
  }

  /// 清除搭档缓存
  Future<void> clearPartners() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_partnersKey);
      await prefs.remove(_lastUpdateKey);
      print('[搭档存储] 已清除缓存');
    } catch (e) {
      print('[搭档存储] 清除失败: $e');
    }
  }
}
