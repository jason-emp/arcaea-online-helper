import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/score_data.dart';
import '../models/score_sort_option.dart';
import '../models/b30r10_data.dart';

/// 成绩存储服务
/// 负责成绩数据的本地持久化
class ScoreStorageService {
  static const String _scoresKey = 'cached_scores';
  static const String _lastUpdateKey = 'scores_last_update';
  static const String _totalCountKey = 'scores_total_count';
  static const String _playerPTTKey = 'scores_player_ptt';
  static const String _sortOptionKey = 'score_sort_option';
  static const String _b30DataKey = 'cached_b30_data';

  /// 保存成绩列表
  Future<void> saveScores(List<ScoreData> scores) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 保存前先去重，确保同一曲目同一难度只保留最高分
      final deduplicatedScores = _deduplicateScores(scores);
      
      // 将成绩列表转换为JSON
      final scoresJson = deduplicatedScores.map((s) => s.toJson()).toList();
      final jsonString = jsonEncode(scoresJson);
      
      // 保存到SharedPreferences
      await prefs.setString(_scoresKey, jsonString);
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      await prefs.setInt(_totalCountKey, deduplicatedScores.length);
      
      print('[ScoreStorage] 已保存 ${deduplicatedScores.length} 条成绩');
    } catch (e) {
      print('[ScoreStorage] 保存失败: $e');
      rethrow;
    }
  }

  /// 成绩去重
  /// 去重规则：相同歌曲标题 + 相同难度，只保留分数最高的
  List<ScoreData> _deduplicateScores(List<ScoreData> scores) {
    final Map<String, ScoreData> scoreMap = {};
    
    for (var score in scores) {
      // 生成唯一键：歌曲标题_难度
      final key = '${score.songTitle}_${score.difficulty}';
      
      // 如果key已存在，比较分数，保留分数更高的
      if (scoreMap.containsKey(key)) {
        final existing = scoreMap[key]!;
        if (score.score > existing.score) {
          // 新成绩分数更高，替换旧成绩
          scoreMap[key] = score;
        }
        // 否则保留现有的（分数更高或相等）
      } else {
        // 首次遇到该曲目+难度，直接添加
        scoreMap[key] = score;
      }
    }
    
    return scoreMap.values.toList();
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
      await prefs.remove(_playerPTTKey);
      
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
      
      // 合并去重（基于歌曲标题 + 难度，保留分数最高的）
      final Map<String, ScoreData> scoreMap = {};
      
      // 先添加现有成绩
      for (var score in existingScores) {
        final key = '${score.songTitle}_${score.difficulty}';
        scoreMap[key] = score;
      }
      
      // 再添加新成绩，如果遇到相同曲目+难度，比较分数并保留更高的
      for (var score in newScores) {
        final key = '${score.songTitle}_${score.difficulty}';
        if (scoreMap.containsKey(key)) {
          final existing = scoreMap[key]!;
          if (score.score > existing.score) {
            // 新成绩分数更高，替换
            scoreMap[key] = score;
          }
          // 否则保留现有的
        } else {
          // 首次遇到该曲目+难度
          scoreMap[key] = score;
        }
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

  /// 保存最近一次获取到的总PTT
  Future<void> savePlayerPTT(double? ptt) async {
    final prefs = await SharedPreferences.getInstance();
    if (ptt == null) {
      await prefs.remove(_playerPTTKey);
    } else {
      await prefs.setDouble(_playerPTTKey, ptt);
    }
  }

  /// 读取缓存的总PTT
  Future<double?> getPlayerPTT() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_playerPTTKey);
    } catch (e) {
      return null;
    }
  }

  /// 保存排序选项
  Future<void> saveSortOption(ScoreSortOption option) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sortOptionKey, option.name);
      print('[ScoreStorage] 已保存排序选项: ${option.label}');
    } catch (e) {
      print('[ScoreStorage] 保存排序选项失败: $e');
    }
  }

  /// 加载排序选项
  Future<ScoreSortOption> loadSortOption() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final optionName = prefs.getString(_sortOptionKey);
      
      if (optionName == null) {
        return ScoreSortOption.dateDescending; // 默认按日期倒序
      }
      
      return ScoreSortOption.fromString(optionName);
    } catch (e) {
      print('[ScoreStorage] 加载排序选项失败: $e');
      return ScoreSortOption.dateDescending;
    }
  }

  /// 保存B30/R10数据
  Future<void> saveB30Data(B30R10Data data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data.toJson());
      await prefs.setString(_b30DataKey, jsonString);
      print('[ScoreStorage] 已保存 B30/R10 数据');
    } catch (e) {
      print('[ScoreStorage] 保存 B30/R10 数据失败: $e');
    }
  }

  /// 加载B30/R10数据
  Future<B30R10Data?> loadB30Data() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_b30DataKey);

      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      return B30R10Data.fromJson(jsonData);
    } catch (e) {
      print('[ScoreStorage] 加载 B30/R10 数据失败: $e');
      return null;
    }
  }
}
