import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_update_service.dart';
import 'score_fetch_service.dart';
import 'score_storage_service.dart';

/// 后台自动更新服务
/// 负责在应用启动时自动更新曲目数据和成绩列表
class BackgroundUpdateService {
  static const String _lastAutoUpdateKey = 'last_auto_update_time';
  static const String _autoUpdateEnabledKey = 'auto_update_enabled';
  static const Duration _updateInterval = Duration(hours: 6); // 每6小时更新一次

  final DataUpdateService _dataUpdateService = DataUpdateService();
  final ScoreFetchService _scoreFetchService = ScoreFetchService();
  final ScoreStorageService _storageService = ScoreStorageService();

  bool _isUpdating = false;
  final _updateStatusController = StreamController<String>.broadcast();

  /// 更新状态流
  Stream<String> get updateStatusStream => _updateStatusController.stream;

  /// 是否正在更新
  bool get isUpdating => _isUpdating;

  /// 检查是否需要自动更新
  Future<bool> shouldAutoUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 检查是否启用自动更新（默认启用）
      final isEnabled = prefs.getBool(_autoUpdateEnabledKey) ?? true;
      if (!isEnabled) {
        return false;
      }

      // 获取上次自动更新时间
      final lastUpdateString = prefs.getString(_lastAutoUpdateKey);
      if (lastUpdateString == null) {
        return true; // 从未更新过，需要更新
      }

      final lastUpdate = DateTime.tryParse(lastUpdateString);
      if (lastUpdate == null) {
        return true;
      }

      // 检查距离上次更新是否超过指定时间间隔
      final now = DateTime.now();
      return now.difference(lastUpdate) > _updateInterval;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('检查自动更新失败: $e');
      }
      return false;
    }
  }

  /// 设置是否启用自动更新
  Future<void> setAutoUpdateEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoUpdateEnabledKey, enabled);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('设置自动更新失败: $e');
      }
    }
  }

  /// 获取是否启用自动更新
  Future<bool> isAutoUpdateEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoUpdateEnabledKey) ?? true;
    } catch (e) {
      return true; // 默认启用
    }
  }

  /// 执行后台自动更新
  /// [forceUpdate] - 是否强制更新（忽略时间间隔检查）
  Future<void> performAutoUpdate({bool forceUpdate = false}) async {
    if (_isUpdating) {
      if (kDebugMode) {
        debugPrint('后台更新已在进行中，跳过');
      }
      return;
    }

    // 检查是否需要更新
    if (!forceUpdate && !await shouldAutoUpdate()) {
      if (kDebugMode) {
        debugPrint('未到更新时间间隔，跳过后台更新');
      }
      return;
    }

    _isUpdating = true;
    _updateStatusController.add('开始后台更新...');

    try {
      // 第一步：更新曲目数据
      if (kDebugMode) {
        debugPrint('后台更新: 开始更新曲目数据');
      }
      _updateStatusController.add('正在更新曲目数据...');

      final dataUpdateResult = await _dataUpdateService.updateAllData();
      if (dataUpdateResult.success) {
        if (kDebugMode) {
          debugPrint('后台更新: 曲目数据更新成功');
        }
        _updateStatusController.add('曲目数据更新成功');
      } else {
        if (kDebugMode) {
          debugPrint('后台更新: 曲目数据更新失败 - ${dataUpdateResult.message}');
        }
        _updateStatusController.add('曲目数据更新失败: ${dataUpdateResult.message}');
        // 曲目数据更新失败，但继续尝试更新成绩
      }

      // 第二步：检查是否有已缓存的成绩
      final hasScores = (await _storageService.loadScores()).isNotEmpty;

      if (hasScores) {
        // 如果有成绩，执行增量更新
        if (kDebugMode) {
          debugPrint('后台更新: 开始增量更新成绩列表');
        }
        _updateStatusController.add('正在增量更新成绩列表...');

        try {
          // 使用静默模式更新（不显示UI进度）
          await _performSilentScoreUpdate();

          if (kDebugMode) {
            debugPrint('后台更新: 成绩列表更新完成');
          }
          _updateStatusController.add('成绩列表更新完成');
        } catch (e) {
          if (kDebugMode) {
            debugPrint('后台更新: 成绩列表更新失败 - $e');
          }
          _updateStatusController.add('成绩列表更新失败');
        }
      } else {
        if (kDebugMode) {
          debugPrint('后台更新: 无缓存成绩，跳过成绩更新');
        }
        _updateStatusController.add('无缓存成绩，跳过成绩更新');
      }

      // 记录本次更新时间
      await _saveLastUpdateTime();

      _updateStatusController.add('后台更新完成');
      if (kDebugMode) {
        debugPrint('后台更新: 全部完成');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('后台更新失败: $e');
      }
      _updateStatusController.add('后台更新失败: $e');
    } finally {
      _isUpdating = false;
    }
  }

  /// 静默更新成绩（后台模式）
  Future<void> _performSilentScoreUpdate() async {
    final completer = Completer<void>();

    // 监听错误
    final errorSub = _scoreFetchService.errorStream.listen((error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    // 监听进度完成
    final progressSub = _scoreFetchService.progressStream.listen((progress) {
      if (progress == -1 && !completer.isCompleted) {
        // 进度为-1表示完成
        completer.complete();
      }
    });

    try {
      // 触发更新（仅更新新增成绩）
      unawaited(_scoreFetchService.startUpdating());

      // 等待完成或超时（最多等待5分钟）
      await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _scoreFetchService.stopFetching();
          throw TimeoutException('成绩更新超时');
        },
      );
    } finally {
      await errorSub.cancel();
      await progressSub.cancel();
    }
  }

  /// 保存更新时间
  Future<void> _saveLastUpdateTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastAutoUpdateKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('保存更新时间失败: $e');
      }
    }
  }

  /// 获取上次自动更新时间
  Future<DateTime?> getLastAutoUpdateTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString(_lastAutoUpdateKey);
      if (timeString == null) {
        return null;
      }
      return DateTime.tryParse(timeString);
    } catch (e) {
      return null;
    }
  }

  /// 清理资源
  void dispose() {
    _scoreFetchService.dispose();
    _updateStatusController.close();
  }
}
