import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/score_data.dart';

/// 成绩存储服务
/// 负责成绩数据的本地持久化
class ScoreStorageService {
  static const String _scoresKey = 'cached_scores';
  static const String _lastUpdateKey = 'scores_last_update';
  static const String _totalCountKey = 'scores_total_count';

  /// 保存成绩列表
  Future<void> saveScores(List<ScoreData> scores) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 将成绩列表转换为JSON
      final scoresJson = scores.map((s) => s.toJson()).toList();
      final jsonString = jsonEncode(scoresJson);
      
      // 保存到SharedPreferences
      await prefs.setString(_scoresKey, jsonString);
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      await prefs.setInt(_totalCountKey, scores.length);
      
      print('[ScoreStorage] 已保存 ${scores.length} 条成绩');
    } catch (e) {
      print('[ScoreStorage] 保存失败: $e');
      rethrow;
    }
  }

  /// 加载成绩列表
  Future<List<ScoreData>> loadScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_scoresKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        print('[ScoreStorage] 没有缓存的成绩数据');
        return [];
      }
      
      // 解析JSON
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final scores = jsonList.map((json) => ScoreData.fromJson(json)).toList();
      
      print('[ScoreStorage] 已加载 ${scores.length} 条成绩');
      return scores;
    } catch (e) {
      print('[ScoreStorage] 加载失败: $e');
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
      print('[ScoreStorage] 获取更新时间失败: $e');
      return null;
    }
  }

  /// 获取缓存的成绩总数
  Future<int> getCachedScoreCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_totalCountKey) ?? 0;
    } catch (e) {
      print('[ScoreStorage] 获取总数失败: $e');
      return 0;
    }
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scoresKey);
      await prefs.remove(_lastUpdateKey);
      await prefs.remove(_totalCountKey);
      
      print('[ScoreStorage] 缓存已清除');
    } catch (e) {
      print('[ScoreStorage] 清除缓存失败: $e');
      rethrow;
    }
  }

  /// 追加新成绩（用于增量更新）
  Future<void> appendScores(List<ScoreData> newScores) async {
    try {
      final existingScores = await loadScores();
      
      // 合并去重（基于歌曲标题、难度、分数和日期）
      final Map<String, ScoreData> scoreMap = {};
      
      for (var score in existingScores) {
        final key = '${score.songTitle}_${score.difficulty}_${score.score}_${score.obtainedDate}';
        scoreMap[key] = score;
      }
      
      for (var score in newScores) {
        final key = '${score.songTitle}_${score.difficulty}_${score.score}_${score.obtainedDate}';
        scoreMap[key] = score;
      }
      
      final mergedScores = scoreMap.values.toList();
      await saveScores(mergedScores);
      
      print('[ScoreStorage] 已追加成绩，总数: ${mergedScores.length}');
    } catch (e) {
      print('[ScoreStorage] 追加成绩失败: $e');
      rethrow;
    }
  }

  /// 检查是否有缓存
  Future<bool> hasCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_scoresKey);
    } catch (e) {
      return false;
    }
  }
}
