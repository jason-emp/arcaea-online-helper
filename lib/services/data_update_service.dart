import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 数据更新结果
class DataUpdateResult {
  final bool success;
  final String message;
  final DateTime? lastUpdateTime;

  DataUpdateResult({
    required this.success,
    required this.message,
    this.lastUpdateTime,
  });
}

/// 数据更新服务
/// 从GitHub下载最新的Songlist.json、ChartConstant.json和chart-data.json
class DataUpdateService {
  static const String _songlistUrl =
      'https://raw.githubusercontent.com/DarrenDanielDay/arcaea-toolbelt-data/main/src/data/songlist.json';
  static const String _chartConstantUrl =
      'https://raw.githubusercontent.com/DarrenDanielDay/arcaea-toolbelt-data/main/src/data/ChartConstant.json';
  static const String _chartDataUrl =
      'https://raw.githubusercontent.com/DarrenDanielDay/arcaea-toolbelt-data/main/src/data/chart-data.json';

  /// 更新所有数据文件
  Future<DataUpdateResult> updateAllData() async {
    try {
      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final dataDir = Directory('${directory.path}/arcaea_data');
      
      // 确保目录存在
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }

      // 下载并保存Songlist.json
      final songlistResult = await _downloadFile(
        _songlistUrl,
        '${dataDir.path}/Songlist.json',
      );
      
      if (!songlistResult) {
        return DataUpdateResult(
          success: false,
          message: '下载 Songlist.json 失败',
        );
      }

      // 下载并保存ChartConstant.json
      final chartConstantResult = await _downloadFile(
        _chartConstantUrl,
        '${dataDir.path}/ChartConstant.json',
      );
      
      if (!chartConstantResult) {
        return DataUpdateResult(
          success: false,
          message: '下载 ChartConstant.json 失败',
        );
      }

      // 下载并保存chart-data.json
      final chartDataResult = await _downloadFile(
        _chartDataUrl,
        '${dataDir.path}/chart-data.json',
      );
      
      if (!chartDataResult) {
        return DataUpdateResult(
          success: false,
          message: '下载 chart-data.json 失败',
        );
      }

      // 更新成功，记录时间
      final now = DateTime.now();
      await _saveLastUpdateTime(now);

      return DataUpdateResult(
        success: true,
        message: '数据更新成功',
        lastUpdateTime: now,
      );
    } catch (e) {
      return DataUpdateResult(
        success: false,
        message: '更新失败: $e',
      );
    }
  }

  /// 下载文件并保存到本地
  Future<bool> _downloadFile(String url, String savePath) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode != 200) {
        return false;
      }

      // 验证JSON格式
      try {
        jsonDecode(response.body);
      } catch (e) {
        return false;
      }

      // 保存到文件
      final file = File(savePath);
      await file.writeAsString(response.body);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取上次更新时间
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/arcaea_data/last_update.txt');
      
      if (!await file.exists()) {
        return null;
      }

      final timeString = await file.readAsString();
      return DateTime.tryParse(timeString);
    } catch (e) {
      return null;
    }
  }

  /// 保存更新时间
  Future<void> _saveLastUpdateTime(DateTime time) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dataDir = Directory('${directory.path}/arcaea_data');
      
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }

      final file = File('${dataDir.path}/last_update.txt');
      await file.writeAsString(time.toIso8601String());
    } catch (e) {
      // 忽略保存时间戳的错误
    }
  }

  /// 检查是否有本地数据
  Future<bool> hasLocalData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final songlistFile = File('${directory.path}/arcaea_data/Songlist.json');
      final chartFile = File('${directory.path}/arcaea_data/ChartConstant.json');
      final chartDataFile = File('${directory.path}/arcaea_data/chart-data.json');
      
      return await songlistFile.exists() && 
             await chartFile.exists() && 
             await chartDataFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// 获取本地数据文件内容
  Future<String?> getLocalData(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/arcaea_data/$fileName');
      
      if (!await file.exists()) {
        // 如果本地没有，尝试从assets读取
        return await rootBundle.loadString('assets/data/$fileName');
      }

      return await file.readAsString();
    } catch (e) {
      // 回退到assets
      try {
        return await rootBundle.loadString('assets/data/$fileName');
      } catch (e) {
        return null;
      }
    }
  }
}
