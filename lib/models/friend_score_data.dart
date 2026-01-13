/// 好友成绩数据模型
/// 从官网的好友排行榜获取的成绩信息
class FriendScoreData {
  final String username; // 好友用户名
  final int score; // 分数
  final String grade; // 评级 (EX+, EX, AA, A, etc.)
  final String characterIconUrl; // 角色头像URL
  final int rank; // 排名
  final String songTitle; // 歌曲标题
  final String artist; // 艺术家
  final String albumArtUrl; // 专辑封面URL
  final String difficulty; // 难度 (PST, PRS, FTR, ETR, BYD)

  FriendScoreData({
    required this.username,
    required this.score,
    required this.grade,
    required this.characterIconUrl,
    required this.rank,
    required this.songTitle,
    required this.artist,
    required this.albumArtUrl,
    required this.difficulty,
  });

  /// 安全地将动态值转换为int（兼容iOS上JavaScript返回double的情况）
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory FriendScoreData.fromJson(Map<String, dynamic> json) {
    return FriendScoreData(
      username: json['username'] as String,
      score: _toInt(json['score']),
      grade: json['grade'] as String,
      characterIconUrl: json['characterIconUrl'] as String,
      rank: _toInt(json['rank']),
      songTitle: json['songTitle'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      albumArtUrl: json['albumArtUrl'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'FTR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'score': score,
      'grade': grade,
      'characterIconUrl': characterIconUrl,
      'rank': rank,
      'songTitle': songTitle,
      'artist': artist,
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

  @override
  String toString() {
    return 'FriendScoreData(username: $username, score: $score, grade: $grade, rank: $rank, songTitle: $songTitle)';
  }
}

/// 歌曲好友成绩数据（包含该歌曲的所有好友成绩）
class SongFriendScores {
  final String songTitle; // 歌曲标题
  final String artist; // 艺术家
  final String albumArtUrl; // 专辑封面URL
  final String difficulty; // 难度
  final List<FriendScoreData> friendScores; // 好友成绩列表

  SongFriendScores({
    required this.songTitle,
    required this.artist,
    required this.albumArtUrl,
    required this.difficulty,
    required this.friendScores,
  });

  factory SongFriendScores.fromJson(Map<String, dynamic> json) {
    return SongFriendScores(
      songTitle: json['songTitle'] as String,
      artist: json['artist'] as String,
      albumArtUrl: json['albumArtUrl'] as String,
      difficulty: json['difficulty'] as String,
      friendScores: (json['friendScores'] as List<dynamic>)
          .map((e) => FriendScoreData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songTitle': songTitle,
      'artist': artist,
      'albumArtUrl': albumArtUrl,
      'difficulty': difficulty,
      'friendScores': friendScores.map((e) => e.toJson()).toList(),
    };
  }

  /// 生成唯一键（用于去重和存储）
  String get key => '${songTitle}_$difficulty';
}

/// 好友成绩列表响应
class FriendScoreListResponse {
  final List<SongFriendScores> songs;
  final int currentPage;
  final bool hasNextPage;
  final String currentDifficulty;

  FriendScoreListResponse({
    required this.songs,
    required this.currentPage,
    required this.hasNextPage,
    required this.currentDifficulty,
  });
}
