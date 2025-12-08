/// 成绩排序选项枚举
enum ScoreSortOption {
  /// 按日期倒序（最新在前）
  dateDescending('按日期倒序', '最新在前'),
  
  /// 按曲名
  songTitle('按曲名', '字母顺序'),
  
  /// 按定数
  constant('按定数', '从高到低'),
  
  /// 按单曲PTT倒序
  pttDescending('按单曲PTT倒序', '从高到低'),
  
  /// 按成绩倒序
  scoreDescending('按成绩倒序', '从高到低'),
  
  /// 按成绩顺序
  scoreAscending('按成绩顺序', '从低到高'),
  
  /// 按目标顺序
  targetAscending('按目标顺序', '从低到高'),
  
  /// 按目标倒序
  targetDescending('按目标倒序', '从高到低'),
  
  /// 按目标与分数之差顺序
  targetDiffAscending('按目标差顺序', '差值从小到大'),
  
  /// 按目标与分数之差倒序
  targetDiffDescending('按目标差倒序', '差值从大到小');

  final String label;
  final String description;

  const ScoreSortOption(this.label, this.description);

  /// 从字符串转换
  static ScoreSortOption fromString(String value) {
    return ScoreSortOption.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ScoreSortOption.dateDescending,
    );
  }
}
