import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/friend_score_data.dart';

/// 好友成绩存储服务
/// 负责好友成绩数据的本地持久化
class FriendScoreStorageService {
  static const String _friendScoresKey = 'cached_friend_scores';
  static const String _lastUpdateKey = 'friend_scores_last_update';

  /// 保存好友成绩
  Future<void> saveFriendScores(List<SongFriendScores> songs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = songs.map((s) => s.toJson()).toList();
      final jsonString = jsonEncode(songsJson);
      await prefs.setString(_friendScoresKey, jsonString);
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
    } catch (e) {
      rethrow;
    }
  }

  /// 追加好友成绩（合并去重）
  Future<void> appendFriendScores(List<SongFriendScores> newSongs) async {
    try {
      final existingSongs = await loadFriendScores();
      final songMap = <String, SongFriendScores>{};

      // 先添加已有的
      for (final song in existingSongs) {
        songMap[song.key] = song;
      }

      // 再添加新的（会覆盖已有的）
      for (final song in newSongs) {
        songMap[song.key] = song;
      }

      await saveFriendScores(songMap.values.toList());
    } catch (e) {
      rethrow;
    }
  }

  /// 加载好友成绩
  Future<List<SongFriendScores>> loadFriendScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_friendScoresKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => SongFriendScores.fromJson(json)).toList();
    } catch (e) {
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

  /// 清除所有缓存
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_friendScoresKey);
      await prefs.remove(_lastUpdateKey);
    } catch (e) {
      rethrow;
    }
  }
}
