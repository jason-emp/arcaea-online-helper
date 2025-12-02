import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../core/constants.dart';

/// 版本更新检查结果
class UpdateCheckResult {
  final bool hasUpdate;
  final String? currentVersion;
  final String? latestVersion;
  final String message;

  UpdateCheckResult({
    required this.hasUpdate,
    this.currentVersion,
    this.latestVersion,
    required this.message,
  });
}

/// 应用更新检查服务
class UpdateService {
  String? _currentVersion;

  /// 获取当前应用版本
  Future<String?> getCurrentVersion() async {
    if (_currentVersion != null) return _currentVersion;

    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;
      return _currentVersion;
    } catch (e) {
      return null;
    }
  }

  /// 检查是否有更新
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();
      if (currentVersion == null) {
        return UpdateCheckResult(
          hasUpdate: false,
          message: '无法获取当前版本信息',
        );
      }

      final uri = Uri.parse(AppConstants.githubApiUrl);
      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        throw Exception('GitHub 返回 ${response.statusCode}');
      }

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersionRaw = (jsonBody['tag_name'] ?? jsonBody['name'] ?? '').toString().trim();

      if (latestVersionRaw.isEmpty) {
        throw const FormatException('未能获取最新版本号');
      }

      final hasUpdate = _isVersionNewer(latestVersionRaw, currentVersion);
      final message = hasUpdate
          ? '发现新版本 $latestVersionRaw，可点击下方"下载最新版本"'
          : '当前版本 $currentVersion 已是最新';

      return UpdateCheckResult(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersionRaw,
        message: message,
      );
    } catch (e) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: _currentVersion,
        message: '检查更新失败: $e',
      );
    }
  }

  /// 比较版本号，判断latest是否比current新
  bool _isVersionNewer(String latest, String current) {
    final latestParts = _versionStringToParts(latest);
    final currentParts = _versionStringToParts(current);
    final maxLength = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var i = 0; i < maxLength; i++) {
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      if (latestPart > currentPart) {
        return true;
      }
      if (latestPart < currentPart) {
        return false;
      }
    }
    return false;
  }

  /// 将版本字符串转换为数字列表
  List<int> _versionStringToParts(String version) {
    var sanitized = version.trim();
    if (sanitized.toLowerCase().startsWith('v')) {
      sanitized = sanitized.substring(1);
    }

    final numericPortion = sanitized.split(RegExp(r'[^0-9\.]')).firstWhere(
          (segment) => segment.isNotEmpty,
          orElse: () => '0',
        );

    return numericPortion
        .split('.')
        .where((segment) => segment.isNotEmpty)
        .map((segment) => int.tryParse(segment) ?? 0)
        .toList();
  }
}
