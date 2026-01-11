import 'package:intl/intl.dart';

/// 格式化工具类
/// 提供分数、日期、时间等格式化方法
class Formatters {
  Formatters._();

  /// 格式化分数为 8 位显示格式
  /// 例如: 9929880 -> "09929880"
  static String formatScore(int score) {
    return score.toString().padLeft(8, '0');
  }

  /// 根据分数获取评级
  /// 
  /// 评级标准:
  /// - PM: >= 10,000,000
  /// - EX+: >= 9,900,000
  /// - EX: >= 9,800,000
  /// - AA: >= 9,500,000
  /// - A: >= 9,200,000
  /// - B: >= 8,900,000
  /// - C: >= 8,600,000
  /// - D: < 8,600,000
  static String getScoreGrade(int score) {
    if (score >= 10000000) return 'PM';
    if (score >= 9900000) return 'EX+';
    if (score >= 9800000) return 'EX';
    if (score >= 9500000) return 'AA';
    if (score >= 9200000) return 'A';
    if (score >= 8900000) return 'B';
    if (score >= 8600000) return 'C';
    return 'D';
  }

  /// 格式化分数为带逗号的显示格式
  /// 例如: 9929880 -> "09,929,880"
  static String formatScoreWithCommas(int score) {
    final scoreStr = score.toString().padLeft(8, '0');
    return '${scoreStr.substring(0, 2)},${scoreStr.substring(2, 5)},${scoreStr.substring(5)}';
  }

  /// 格式化日期时间为标准格式
  /// 格式: yyyy-MM-dd HH:mm
  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化日期时间为相对时间
  /// 例如: "刚刚", "5分钟前", "3天前"
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} 小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else {
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    }
  }

  /// 解析日期字符串，支持多种格式
  /// 支持格式:
  /// - yyyy/MM/dd, yyyy/M/d
  /// - yyyy-MM-dd, yyyy-M-d
  /// - M/d/yyyy
  /// - 以上格式 + HH:mm 或 H:mm
  static DateTime? parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    final bool usesSlash = dateStr.contains('/');
    final bool usesDash = dateStr.contains('-');
    final bool hasTime = dateStr.contains(':');

    List<String> formats;

    if (usesSlash && !usesDash) {
      final parts = dateStr.split(RegExp(r'[/\s:]'));
      if (parts.isNotEmpty && parts[0].length == 4) {
        // yyyy/M/d 格式
        formats = hasTime
            ? ['yyyy/MM/dd HH:mm', 'yyyy/MM/dd H:mm', 'yyyy/M/d HH:mm', 'yyyy/M/d H:mm']
            : ['yyyy/MM/dd', 'yyyy/M/d'];
      } else {
        // M/d/yyyy 格式
        formats = hasTime
            ? ['M/d/yyyy HH:mm', 'M/d/yyyy H:mm']
            : ['M/d/yyyy'];
      }
    } else if (usesDash && !usesSlash) {
      formats = hasTime
          ? ['yyyy-MM-dd HH:mm', 'yyyy-MM-dd H:mm', 'yyyy-M-d HH:mm', 'yyyy-M-d H:mm']
          : ['yyyy-MM-dd', 'yyyy-M-d'];
    } else {
      // 尝试所有格式
      formats = [
        'M/d/yyyy HH:mm', 'M/d/yyyy H:mm', 'M/d/yyyy',
        'yyyy-MM-dd HH:mm', 'yyyy-MM-dd H:mm', 'yyyy-MM-dd',
        'yyyy-M-d HH:mm', 'yyyy-M-d H:mm', 'yyyy-M-d',
        'yyyy/MM/dd HH:mm', 'yyyy/MM/dd H:mm', 'yyyy/MM/dd',
        'yyyy/M/d HH:mm', 'yyyy/M/d H:mm', 'yyyy/M/d',
      ];
    }

    for (final format in formats) {
      try {
        final date = DateFormat(format).parseStrict(dateStr);
        if (date.year >= 1900 && date.year <= 2100) {
          return date;
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }
}
