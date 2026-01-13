import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/friend_data.dart';

/// 好友存储服务
/// 负责好友数据的本地持久化
class FriendStorageService {
  static const String _friendsKey = 'cached_friends';
  static const String _lastUpdateKey = 'friends_last_update';

  /// 保存好友列表
  Future<void> saveFriends(List<FriendData> friends) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 将好友列表转换为JSON
      final friendsJson = friends.map((f) => f.toJson()).toList();
      final jsonString = jsonEncode(friendsJson);

      // 保存到SharedPreferences
      await prefs.setString(_friendsKey, jsonString);
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());

      print('[好友存储] 已保存 ${friends.length} 个好友');
    } catch (e) {
      print('[好友存储] 保存失败: $e');
      rethrow;
    }
  }

  /// 加载好友列表
  Future<List<FriendData>> loadFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_friendsKey);

      if (jsonString == null || jsonString.isEmpty) {
        print('[好友存储] 无缓存数据');
        return [];
      }

      // 解析JSON
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final friends =
          jsonList.map((json) => FriendData.fromJson(json)).toList();

      print('[好友存储] 已加载 ${friends.length} 个好友');
      return friends;
    } catch (e) {
      print('[好友存储] 加载失败: $e');
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

  /// 清除好友缓存
  Future<void> clearFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_friendsKey);
      await prefs.remove(_lastUpdateKey);
      print('[好友存储] 已清除缓存');
    } catch (e) {
      print('[好友存储] 清除失败: $e');
    }
  }
}
