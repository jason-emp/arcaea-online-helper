/// 好友数据模型
class FriendData {
  final String username;
  final String lastActiveTime; // e.g. "15m", "36m", "3h", "4h", "1d", "19d", "1M", "5M", "1Y"
  final String songName; // e.g. "SOUNDWiTCH [FTR][EX+]"
  final String characterIconUrl;
  final String ratingClass; // e.g. "rating_5", "rating_6", etc.
  final String ratingImageUrl;
  final double ratingValue; // e.g. 12.44
  final bool isMutual; // 是否为互相好友

  FriendData({
    required this.username,
    required this.lastActiveTime,
    required this.songName,
    required this.characterIconUrl,
    required this.ratingClass,
    required this.ratingImageUrl,
    required this.ratingValue,
    required this.isMutual,
  });

  factory FriendData.fromJson(Map<String, dynamic> json) {
    return FriendData(
      username: json['username'] as String,
      lastActiveTime: json['lastActiveTime'] as String,
      songName: json['songName'] as String,
      characterIconUrl: json['characterIconUrl'] as String,
      ratingClass: json['ratingClass'] as String,
      ratingImageUrl: json['ratingImageUrl'] as String,
      ratingValue: (json['ratingValue'] as num).toDouble(),
      isMutual: json['isMutual'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'lastActiveTime': lastActiveTime,
      'songName': songName,
      'characterIconUrl': characterIconUrl,
      'ratingClass': ratingClass,
      'ratingImageUrl': ratingImageUrl,
      'ratingValue': ratingValue,
      'isMutual': isMutual,
    };
  }

  /// 获取评分显示文本（整数部分）
  String get ratingDecimal => ratingValue.floor().toString();

  /// 获取评分显示文本（小数部分）
  String get ratingFixed {
    final decimal = (ratingValue * 100).round() % 100;
    return decimal.toString().padLeft(2, '0');
  }

  @override
  String toString() {
    return 'FriendData(username: $username, rating: $ratingValue, lastActive: $lastActiveTime)';
  }
}
