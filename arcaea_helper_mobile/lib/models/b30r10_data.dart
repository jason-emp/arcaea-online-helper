/// B30/R10 数据模型
/// 从Chrome扩展或WebView导出的数据结构
class B30R10Data {
  final PlayerData player;
  final List<SongCardData> best30;
  final List<SongCardData> recent10;

  B30R10Data({
    required this.player,
    required this.best30,
    required this.recent10,
  });

  factory B30R10Data.fromJson(Map<String, dynamic> json) {
    return B30R10Data(
      player: PlayerData.fromJson(json['player'] as Map<String, dynamic>),
      best30: (json['best30'] as List<dynamic>)
          .map((e) => SongCardData.fromJson(e as Map<String, dynamic>))
          .toList(),
      recent10: (json['recent10'] as List<dynamic>)
          .map((e) => SongCardData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'player': player.toJson(),
      'best30': best30.map((e) => e.toJson()).toList(),
      'recent10': recent10.map((e) => e.toJson()).toList(),
    };
  }
}

/// 玩家数据
class PlayerData {
  final String username;
  final double? totalPTT;
  final double? best30Avg;
  final double? recent10Avg;
  final DateTime exportDate;

  PlayerData({
    required this.username,
    this.totalPTT,
    this.best30Avg,
    this.recent10Avg,
    required this.exportDate,
  });

  factory PlayerData.fromJson(Map<String, dynamic> json) {
    return PlayerData(
      username: json['username'] as String,
      totalPTT: json['totalPTT'] != null ? (json['totalPTT'] as num).toDouble() : null,
      best30Avg: json['best30Avg'] != null ? (json['best30Avg'] as num).toDouble() : null,
      recent10Avg: json['recent10Avg'] != null ? (json['recent10Avg'] as num).toDouble() : null,
      exportDate: DateTime.parse(json['exportDate'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'totalPTT': totalPTT,
      'best30Avg': best30Avg,
      'recent10Avg': recent10Avg,
      'exportDate': exportDate.toIso8601String(),
    };
  }
}

/// 歌曲卡片数据
class SongCardData {
  final String songTitle;
  final String difficulty;
  final int difficultyIndex;
  final int score;
  final double? constant;
  final double? playPTT;
  final String? coverUrl;
  final int rank;

  SongCardData({
    required this.songTitle,
    required this.difficulty,
    required this.difficultyIndex,
    required this.score,
    this.constant,
    this.playPTT,
    this.coverUrl,
    required this.rank,
  });

  factory SongCardData.fromJson(Map<String, dynamic> json) {
    return SongCardData(
      songTitle: json['songTitle'] as String,
      difficulty: json['difficulty'] as String,
      difficultyIndex: json['difficultyIndex'] as int,
      score: json['score'] as int,
      constant: json['constant'] != null ? (json['constant'] as num).toDouble() : null,
      playPTT: json['playPTT'] != null ? (json['playPTT'] as num).toDouble() : null,
      coverUrl: json['coverUrl'] as String?,
      rank: json['rank'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songTitle': songTitle,
      'difficulty': difficulty,
      'difficultyIndex': difficultyIndex,
      'score': score,
      'constant': constant,
      'playPTT': playPTT,
      'coverUrl': coverUrl,
      'rank': rank,
    };
  }
}
