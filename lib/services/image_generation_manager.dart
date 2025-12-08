import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../models/b30r10_data.dart';
import '../services/image_generator_service.dart';
import '../core/constants.dart';

/// 图片生成管理器
class ImageGenerationManager {
  bool _isGenerating = false;
  String _progress = '';
  B30R10Data? _cachedData;

  bool get isGenerating => _isGenerating;
  String get progress => _progress;
  B30R10Data? get cachedData => _cachedData;

  set cachedData(B30R10Data? data) => _cachedData = data;

  /// 生成B30/R10图片
  Future<String> generateImage({
    required BuildContext context,
    required ValueChanged<String> onProgressUpdate,
  }) async {
    if (_cachedData == null) {
      throw Exception('没有可用的数据');
    }

    _isGenerating = true;
    onProgressUpdate('准备生成图片...');

    try {
      // 请求存储权限
      if (Platform.isAndroid || Platform.isIOS) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          final granted = await Gal.requestAccess();
          if (!granted) {
            throw Exception('需要相册访问权限才能保存图片');
          }
        }
      }

      // 生成图片
      final imageBytes = await ImageGeneratorService.generateImage(
        _cachedData!,
        onProgress: (progress) {
          _progress = progress;
          onProgressUpdate(progress);
        },
      );

      // 保存图片
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'arcaea-b30r10-${_cachedData!.player.username}-$timestamp.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      // 保存到相册
      await Gal.putImage(file.path, album: AppConstants.albumName);

      return fileName;
    } finally {
      _isGenerating = false;
      _progress = '';
    }
  }

  void reset() {
    _isGenerating = false;
    _progress = '';
    _cachedData = null;
  }
}
