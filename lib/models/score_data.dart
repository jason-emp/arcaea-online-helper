/// 成绩数据模型
/// 从官网 https://arcaea.lowiro.com/zh/profile/scores 拉取的成绩信息
class ScoreData {
  final String songTitle; // 歌曲标题
  final String artist; // 艺术家/作者
  final int score; // 分数
  final String grade; // 评级 (EX+, AA, A, etc.)
  final String clearType; // Clear类型 (C = Clear)
  final String obtainedDate; // 取得日期
  final String albumArtUrl; // 专辑封面URL
  final String difficulty; // 难度 (PST, PRS, FTR, BYD)

  ScoreData({
    required this.songTitle,
    required this.artist,
    required this.score,
    required this.grade,
    required this.clearType,
    required this.obtainedDate,
    required this.albumArtUrl,
    this.difficulty = 'FTR', // 默认FTR
  });

  factory ScoreData.fromJson(Map<String, dynamic> json) {
    return ScoreData(
      songTitle: json['songTitle'] as String,
      artist: json['artist'] as String,
      score: json['score'] as int,
      grade: json['grade'] as String,
      clearType: json['clearType'] as String,
      obtainedDate: json['obtainedDate'] as String,
      albumArtUrl: json['albumArtUrl'] as String,
      difficulty: json['difficulty'] as String? ?? 'FTR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songTitle': songTitle,
      'artist': artist,
      'score': score,
      'grade': grade,
      'clearType': clearType,
      'obtainedDate': obtainedDate,
      'albumArtUrl': albumArtUrl,
      'difficulty': difficulty,
    };
  }

  /// 格式化分数显示 (例如: 9,929,880 -> 09,929,880)
  String get formattedScore {
    String scoreStr = score.toString().padLeft(8, '0');
    // 添加逗号分隔符
    return '${scoreStr.substring(0, 2)},${scoreStr.substring(2, 5)},${scoreStr.substring(5)}';
  }
}

/// 成绩列表响应
class ScoreListResponse {
  final List<ScoreData> scores;
  final int currentPage;
  final bool hasNextPage;
  final double? playerPTT;

  ScoreListResponse({
    required this.scores,
    required this.currentPage,
    required this.hasNextPage,
    this.playerPTT,
  });

  factory ScoreListResponse.fromJson(Map<String, dynamic> json) {
    return ScoreListResponse(
      scores: (json['scores'] as List<dynamic>)
          .map((e) => ScoreData.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: json['currentPage'] as int,
      hasNextPage: json['hasNextPage'] as bool,
      playerPTT: json['playerPTT'] != null
          ? (json['playerPTT'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scores': scores.map((e) => e.toJson()).toList(),
      'currentPage': currentPage,
      'hasNextPage': hasNextPage,
      'playerPTT': playerPTT,
    };
  }
}
