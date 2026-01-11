/// 难度工具类
/// 处理难度相关的转换和解析
class DifficultyUtils {
  DifficultyUtils._();

  /// 难度索引映射
  static const Map<String, int> _difficultyIndices = {
    'past': 0,
    'pst': 0,
    'present': 1,
    'prs': 1,
    'future': 2,
    'ftr': 2,
    'eternal': 3,
    'etr': 3,
    'beyond': 4,
    'byd': 4,
  };

  /// 难度全称映射
  static const Map<String, String> _difficultyFullNames = {
    'pst': 'Past',
    'prs': 'Present',
    'ftr': 'Future',
    'etr': 'Eternal',
    'byd': 'Beyond',
  };

  /// 解析难度字符串为索引
  /// 
  /// 支持的格式: PST, PRS, FTR, ETR, BYD, Past, Present, Future, Eternal, Beyond
  /// 返回 -1 表示无效的难度
  static int parseDifficultyIndex(String difficulty) {
    final normalized = difficulty.trim().toLowerCase();
    return _difficultyIndices[normalized] ?? -1;
  }

  /// 标准化难度名称为简写
  /// 
  /// 例如: "Future" -> "FTR", "PAST" -> "PST"
  static String normalizeDifficulty(String difficulty) {
    final normalized = difficulty.trim().toLowerCase();
    switch (normalized) {
      case 'past':
      case 'pst':
        return 'PST';
      case 'present':
      case 'prs':
        return 'PRS';
      case 'future':
      case 'ftr':
        return 'FTR';
      case 'eternal':
      case 'etr':
        return 'ETR';
      case 'beyond':
      case 'byd':
        return 'BYD';
      default:
        return difficulty.toUpperCase();
    }
  }

  /// 获取难度全称
  static String getFullName(String difficulty) {
    final normalized = difficulty.trim().toLowerCase();
    return _difficultyFullNames[normalized] ?? difficulty;
  }

  /// 构建歌曲唯一键
  /// 
  /// 用于在 Map 中标识唯一的 歌曲+难度 组合
  static String buildSongKey(String title, String difficulty) {
    return '${title.trim().toLowerCase()}|${difficulty.trim().toUpperCase()}';
  }

  /// 所有难度列表（简写）
  static const List<String> allDifficulties = ['PST', 'PRS', 'FTR', 'ETR', 'BYD'];

  /// 常用难度列表（不含 Eternal）
  static const List<String> commonDifficulties = ['PST', 'PRS', 'FTR', 'BYD'];
}
