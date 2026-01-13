import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('日期解析测试', () {
    DateTime? parseDate(String dateStr) {
      if (dateStr.isEmpty) return null;

      // 先判断日期格式的类型
      final bool usesSlash = dateStr.contains('/');
      final bool usesDash = dateStr.contains('-');
      final bool hasTime = dateStr.contains(':');

      // 根据分隔符和是否有时间来选择格式（优先级排序）
      List<String> formats = [];

      if (usesSlash && !usesDash) {
        // 斜杠格式 - 同时尝试两种格式以兼容所有情况
        if (hasTime) {
          formats = [
            'M/d/yyyy HH:mm', // 1/15/2024 13:45
            'M/d/yyyy H:mm', // 1/15/2024 1:45
            'M/d/yyyy h:mm a', // 1/15/2024 1:45 PM
            'M/d/yyyy hh:mm a', // 1/15/2024 01:45 PM
            'yyyy/MM/dd HH:mm', // 2024/01/15 13:45
            'yyyy/MM/dd H:mm', // 2024/01/15 1:45
            'yyyy/MM/dd h:mm a', // 2024/01/15 1:45 PM
            'yyyy/MM/dd hh:mm a', // 2024/01/15 01:45 PM
            'yyyy/M/d HH:mm', // 2024/1/15 13:45
            'yyyy/M/d H:mm', // 2024/1/15 1:45
            'yyyy/M/d h:mm a', // 2024/1/15 1:45 PM
            'yyyy/M/d hh:mm a', // 2024/1/15 01:45 PM
          ];
        } else {
          formats = [
            'M/d/yyyy', // 1/15/2024
            'yyyy/MM/dd', // 2024/01/15
            'yyyy/M/d', // 2024/1/15
          ];
        }
      } else if (usesDash && !usesSlash) {
        // 破折号格式
        if (hasTime) {
          formats = [
            'yyyy-MM-dd HH:mm', // 2024-01-15 13:45
            'yyyy-MM-dd H:mm', // 2024-01-15 1:45
            'yyyy-MM-dd h:mm a', // 2024-01-15 1:45 PM
            'yyyy-MM-dd hh:mm a', // 2024-01-15 01:45 PM
            'yyyy-M-d HH:mm', // 2024-1-15 13:45
            'yyyy-M-d H:mm', // 2024-1-15 1:45
            'yyyy-M-d h:mm a', // 2024-1-15 1:45 PM
            'yyyy-M-d hh:mm a', // 2024-1-15 01:45 PM
          ];
        } else {
          formats = [
            'yyyy-MM-dd', // 2024-01-15
            'yyyy-M-d', // 2024-1-15
          ];
        }
      } else {
        // 混合格式或其他情况，尝试所有格式
        formats = [
          'M/d/yyyy HH:mm',
          'M/d/yyyy H:mm',
          'M/d/yyyy h:mm a',
          'M/d/yyyy hh:mm a',
          'M/d/yyyy',
          'yyyy-MM-dd HH:mm',
          'yyyy-MM-dd H:mm',
          'yyyy-MM-dd h:mm a',
          'yyyy-MM-dd hh:mm a',
          'yyyy-MM-dd',
          'yyyy-M-d HH:mm',
          'yyyy-M-d H:mm',
          'yyyy-M-d h:mm a',
          'yyyy-M-d hh:mm a',
          'yyyy-M-d',
          'yyyy/MM/dd HH:mm',
          'yyyy/MM/dd H:mm',
          'yyyy/MM/dd h:mm a',
          'yyyy/MM/dd hh:mm a',
          'yyyy/MM/dd',
          'yyyy/M/d HH:mm',
          'yyyy/M/d H:mm',
          'yyyy/M/d h:mm a',
          'yyyy/M/d hh:mm a',
          'yyyy/M/d',
        ];
      }

      // 尝试解析
      for (final format in formats) {
        try {
          final date = DateFormat(format).parseStrict(dateStr);
          // 验证解析结果的合理性（年份应该在1900-2100之间）
          if (date.year >= 1900 && date.year <= 2100) {
            return date;
          }
        } catch (e) {
          // 继续尝试下一个格式
        }
      }

      return null; // 所有格式都失败
    }

    test('应该能解析 M/d/yyyy HH:mm 格式', () {
      final result = parseDate('1/15/2024 13:45');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
      expect(result.hour, 13);
      expect(result.minute, 45);
    });

    test('应该能解析 yyyy/M/d HH:mm 格式', () {
      final result = parseDate('2024/1/15 13:45');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
      expect(result.hour, 13);
      expect(result.minute, 45);
    });

    test('应该能解析 M/d/yyyy H:mm 格式（单数小时）', () {
      final result = parseDate('1/15/2024 1:45');
      expect(result, isNotNull);
      expect(result!.hour, 1);
    });

    test('应该能解析 yyyy-MM-dd HH:mm 格式', () {
      final result = parseDate('2024-01-15 13:45');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('应该能解析 yyyy-M-d HH:mm 格式', () {
      final result = parseDate('2024-1-5 9:30');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 5);
      expect(result.hour, 9);
      expect(result.minute, 30);
    });

    test('应该能解析不带时间的日期', () {
      final result = parseDate('1/15/2024');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('空字符串应返回 null', () {
      final result = parseDate('');
      expect(result, isNull);
    });

    test('无效格式应返回 null', () {
      final result = parseDate('invalid date');
      expect(result, isNull);
    });

    test('应该能解析 12 小时制 AM 格式', () {
      final result = parseDate('1/15/2024 1:45 AM');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
      expect(result.hour, 1);
      expect(result.minute, 45);
    });

    test('应该能解析 12 小时制 PM 格式', () {
      final result = parseDate('1/15/2024 1:45 PM');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
      expect(result.hour, 13); // PM 时 1:45 应该是 13:45
      expect(result.minute, 45);
    });

    test('应该能解析 yyyy/M/d 格式带 AM/PM', () {
      final result = parseDate('2024/1/15 11:30 PM');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
      expect(result.hour, 23); // PM 时 11:30 应该是 23:30
      expect(result.minute, 30);
    });

    test('日期排序应该正确', () {
      final dates = [
        '1/15/2024 13:45',
        '2024/01/10 9:30',
        '2024-01-20 14:00',
        '12/31/2023 23:59',
        '2024/02/01 8:00',
      ];

      dates.sort((a, b) {
        final dateA = parseDate(a);
        final dateB = parseDate(b);

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateB.compareTo(dateA); // 倒序
      });

      // 期望：最新的日期在前
      expect(dates[0], '2024/02/01 8:00');
      expect(dates[1], '2024-01-20 14:00');
      expect(dates[2], '1/15/2024 13:45');
      expect(dates[3], '2024/01/10 9:30');
      expect(dates[4], '12/31/2023 23:59');
    });
  });
}
