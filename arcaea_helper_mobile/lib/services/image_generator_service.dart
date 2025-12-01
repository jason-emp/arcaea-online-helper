import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/b30r10_data.dart';
import 'image_generator_config.dart';

/// Arcaea B30/R10 图片生成服务
/// 移植自 scripts/generate-b30r10-image.js
class ImageGeneratorService {
  /// 绘制顶部模糊背景区域
  static Future<void> _drawBlurredHeader(
    Canvas canvas,
    ui.Image backgroundImage,
    double offsetX,
    double offsetY,
    double scaledWidth,
    double scaledHeight,
  ) async {
    // 计算源图片在顶部区域的裁剪位置
    final headerSrcRect = Rect.fromLTWH(
      offsetX < 0 ? (-offsetX / scaledWidth * backgroundImage.width) : 0,
      offsetY < 0 ? (-offsetY / scaledHeight * backgroundImage.height) : 0,
      (ImageGeneratorConfig.canvasWidth / scaledWidth * backgroundImage.width).clamp(0, backgroundImage.width.toDouble()).toDouble(),
      (ImageGeneratorConfig.headerHeight / scaledHeight * backgroundImage.height).clamp(0, backgroundImage.height.toDouble()).toDouble(),
    );
    
    final headerDstRect = Rect.fromLTWH(
      0,
      0,
      ImageGeneratorConfig.canvasWidth.toDouble(),
      ImageGeneratorConfig.headerHeight.toDouble(),
    );
    
    // 使用 ImageFilter 实现真正的高斯模糊
    canvas.save();
    canvas.clipRect(headerDstRect);
    
    final blurPaint = Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: 30.0, // 水平模糊半径
        sigmaY: 30.0, // 垂直模糊半径
        tileMode: TileMode.clamp,
      );
    
    // 绘制模糊的顶部背景
    canvas.saveLayer(headerDstRect, blurPaint);
    canvas.drawImageRect(backgroundImage, headerSrcRect, headerDstRect, Paint());
    canvas.restore();
    canvas.restore();
    
    // 添加半透明遮罩（加深遮罩）
    final paint = Paint()..color = const Color(0xBF1A1A2E); // 0.75 opacity
    canvas.drawRect(headerDstRect, paint);
  }
  /// 根据分数计算评级
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

  /// 计算目标分数（使PTT +0.01）
  static int? calculateTargetScore(
      double? constant, int currentScore, double? totalPTT) {
    if (constant == null || totalPTT == null) return null;
    if (currentScore >= 10000000) return null;

    final currentDisplayPTT = (totalPTT * 100).floor() / 100;
    final targetDisplayPTT = currentDisplayPTT + 0.01;

    // 计算当前单曲PTT
    double currentPlayPTT;
    if (currentScore >= 10000000) {
      currentPlayPTT = constant + 2;
    } else if (currentScore >= 9800000) {
      currentPlayPTT = constant + 1 + (currentScore - 9800000) / 200000;
    } else {
      currentPlayPTT = constant + (currentScore - 9500000) / 300000;
      if (currentPlayPTT < 0) currentPlayPTT = 0;
    }

    // 二分搜索目标分数
    int left = currentScore + 1;
    int right = 10000000;
    int? result;

    while (left <= right) {
      final mid = ((left + right) / 2).floor();

      // 计算新的单曲PTT
      double newPlayPTT;
      if (mid >= 10000000) {
        newPlayPTT = constant + 2;
      } else if (mid >= 9800000) {
        newPlayPTT = constant + 1 + (mid - 9800000) / 200000;
      } else {
        newPlayPTT = constant + (mid - 9500000) / 300000;
        if (newPlayPTT < 0) newPlayPTT = 0;
      }

      final newTotalPTT = totalPTT - currentPlayPTT / 40 + newPlayPTT / 40;
      final newDisplayPTT = (newTotalPTT * 100).floor() / 100;

      if (newDisplayPTT >= targetDisplayPTT) {
        result = mid;
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    return result;
  }

  /// 加载网络图片（安全版本，失败返回null）
  static Future<ui.Image?> loadImageSafe(String? url) async {
    if (url == null || url.isEmpty) return null;

    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        // 添加必要的请求头
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Referer': 'https://arcaea.lowiro.com/',
          },
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final codec = await ui.instantiateImageCodec(response.bodyBytes);
          final frame = await codec.getNextFrame();
          debugPrint('[ImageGenerator] ✓ 图片加载成功: ${url.split('/').last}');
          return frame.image;
        } else {
          debugPrint('[ImageGenerator] ✗ HTTP ${response.statusCode}: ${url.split('/').last}');
        }
      }
    } catch (e) {
      debugPrint('[ImageGenerator] ✗ 加载失败: ${url.split('/').last} - $e');
    }
    return null;
  }

  /// 绘制圆角矩形路径
  static Path createRoundRectPath(
      double x, double y, double width, double height, double radius) {
    final path = Path();
    path.moveTo(x + radius, y);
    path.lineTo(x + width - radius, y);
    path.quadraticBezierTo(x + width, y, x + width, y + radius);
    path.lineTo(x + width, y + height - radius);
    path.quadraticBezierTo(
        x + width, y + height, x + width - radius, y + height);
    path.lineTo(x + radius, y + height);
    path.quadraticBezierTo(x, y + height, x, y + height - radius);
    path.lineTo(x, y + radius);
    path.quadraticBezierTo(x, y, x + radius, y);
    path.close();
    return path;
  }

  /// 绘制顶部玩家信息（仅文字，不含背景）
  static Future<void> drawHeader(
    Canvas canvas,
    PlayerData playerData,
  ) async {
    final paint = Paint();

    // 绘制文字
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // 玩家名称（居中）
    textPainter.text = TextSpan(
      text: playerData.username,
      style: const TextStyle(
        color: ImageGeneratorConfig.textPrimary,
        fontSize: ImageGeneratorConfig.playerName,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace', // 使用等宽字体提升可读性
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (ImageGeneratorConfig.canvasWidth - textPainter.width) / 2,
        90 - textPainter.height / 2,
      ),
    );

    // PTT信息（居中排列）
    const statsY = 170.0;
    const statsSpacing = 500.0;
    final centerX = ImageGeneratorConfig.canvasWidth / 2;

    // 总PTT
    if (playerData.totalPTT != null) {
      textPainter.text = TextSpan(
        text: '总PTT: ${playerData.totalPTT!.toStringAsFixed(4)}',
        style: const TextStyle(
          color: ImageGeneratorConfig.scoreGold,
          fontSize: ImageGeneratorConfig.playerStats,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          centerX - statsSpacing / 2 - 50 - textPainter.width,
          statsY - textPainter.height / 2,
        ),
      );
    }

    // B30平均
    if (playerData.best30Avg != null) {
      textPainter.text = TextSpan(
        text: 'B30: ${playerData.best30Avg!.toStringAsFixed(4)}',
        style: const TextStyle(
          color: ImageGeneratorConfig.textPrimary,
          fontSize: ImageGeneratorConfig.playerStats,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          centerX - textPainter.width / 2,
          statsY - textPainter.height / 2,
        ),
      );
    }

    // R10平均
    if (playerData.recent10Avg != null) {
      textPainter.text = TextSpan(
        text: 'R10: ${playerData.recent10Avg!.toStringAsFixed(4)}',
        style: const TextStyle(
          color: ImageGeneratorConfig.textPrimary,
          fontSize: ImageGeneratorConfig.playerStats,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          centerX + statsSpacing / 2 + 50,
          statsY - textPainter.height / 2,
        ),
      );
    }

    // 导出日期（居中）
    final dateStr =
        '导出时间: ${playerData.exportDate.toLocal().toString().split('.')[0]}';
    textPainter.text = TextSpan(
      text: dateStr,
      style: const TextStyle(
        color: ImageGeneratorConfig.textTertiary,
        fontSize: ImageGeneratorConfig.playerStatsLabel,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (ImageGeneratorConfig.canvasWidth - textPainter.width) / 2,
        235 - textPainter.height / 2,
      ),
    );
  }

  /// 绘制单个歌曲卡片
  static Future<void> drawCard(
    Canvas canvas,
    SongCardData cardData,
    double x,
    double y,
    double? totalPTT, {
    bool isRecent = false,
    ui.Image? coverImage,
  }) async {
    final paint = Paint();

    // 绘制卡片背景
    canvas.save();
    final cardPath = createRoundRectPath(
      x,
      y,
      ImageGeneratorConfig.cardWidth.toDouble(),
      ImageGeneratorConfig.cardHeight.toDouble(),
      15,
    );
    canvas.clipPath(cardPath);

    // 背景色
    paint.color = ImageGeneratorConfig.cardBg;
    canvas.drawPath(cardPath, paint);

    // 如果有曲绘，绘制为背景（带透明度）
    if (coverImage != null) {
      paint.color = ImageGeneratorConfig.cardBg.withOpacity(0.15);
      final srcRect = Rect.fromLTWH(
        0,
        0,
        coverImage.width.toDouble(),
        coverImage.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(
        x,
        y,
        ImageGeneratorConfig.cardWidth.toDouble(),
        ImageGeneratorConfig.cardHeight.toDouble(),
      );
      canvas.drawImageRect(coverImage, srcRect, dstRect, paint);
    }

    canvas.restore();

    // 绘制边框
    paint
      ..color = ImageGeneratorConfig.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(cardPath, paint);
    paint.style = PaintingStyle.fill;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 排名标签
    final rankText = isRecent ? 'R${cardData.rank}' : '#${cardData.rank}';
    textPainter.text = TextSpan(
      text: rankText,
      style: TextStyle(
        color: isRecent
            ? ImageGeneratorConfig.targetScore
            : ImageGeneratorConfig.scoreGold,
        fontSize: ImageGeneratorConfig.cardRank,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x + 15, y + 45 - textPainter.height / 2));

    // 难度标签（带彩色圆角矩形背景）
    final diffColor = ImageGeneratorConfig.difficultyColors[cardData.difficulty] ??
        ImageGeneratorConfig.primary;
    textPainter.text = TextSpan(
      text: cardData.difficulty,
      style: const TextStyle(
        color: Colors.white,
        fontSize: ImageGeneratorConfig.cardDifficulty,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();

    final diffPadding = 10.0;
    final diffX = x + ImageGeneratorConfig.cardWidth - 15;
    final diffY = y + 45;
    final diffPath = createRoundRectPath(
      diffX - textPainter.width - diffPadding,
      diffY - textPainter.height / 2 - 4,
      textPainter.width + diffPadding * 2,
      textPainter.height + 8,
      6,
    );
    paint.color = diffColor;
    canvas.drawPath(diffPath, paint);
    textPainter.paint(
      canvas,
      Offset(
        diffX - textPainter.width,
        diffY - textPainter.height / 2,
      ),
    );

    // 歌曲名称（自动换行，最多2行）
    final maxTitleWidth = ImageGeneratorConfig.cardWidth - 30.0;
    textPainter.text = TextSpan(
      text: cardData.songTitle,
      style: const TextStyle(
        color: ImageGeneratorConfig.textPrimary,
        fontSize: ImageGeneratorConfig.cardTitle,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout(maxWidth: maxTitleWidth);

    final titleY = y + 90;
    textPainter.paint(canvas, Offset(x + 15, titleY));
    
    // 计算标题实际结束位置（根据行数动态调整）
    final titleEndY = titleY + textPainter.height;

    // 分数
    final scoreText = cardData.score.toString().padLeft(8, '0');
    final formattedScore = '${scoreText.substring(0, 2)}\' ${scoreText.substring(2, 5)}\' ${scoreText.substring(5)}';
    textPainter.text = TextSpan(
      text: formattedScore,
      style: const TextStyle(
        color: ImageGeneratorConfig.scoreGold,
        fontSize: ImageGeneratorConfig.cardScore,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    final scoreY = titleEndY + 55;
    textPainter.paint(canvas, Offset(x + 15, scoreY));

    // 评级（在分数右侧）
    final grade = getScoreGrade(cardData.score);
    final scoreWidth = textPainter.width;
    textPainter.text = TextSpan(
      text: grade,
      style: const TextStyle(
        color: Colors.white,
        fontSize: ImageGeneratorConfig.cardInfo,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x + 15 + scoreWidth + 25, scoreY));

    // 定数和PTT信息（同一行，左右对齐）
    final infoY = scoreY + 55;

    // 定数（左对齐）
    if (cardData.constant != null) {
      textPainter.text = TextSpan(
        text: '定数: ${cardData.constant!.toStringAsFixed(1)}',
        style: const TextStyle(
          color: ImageGeneratorConfig.textSecondary,
          fontSize: ImageGeneratorConfig.cardInfo,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 15, infoY));
    }

    // PTT（右对齐，浅蓝色加粗）
    if (cardData.playPTT != null) {
      textPainter.text = TextSpan(
        text: 'PTT: ${cardData.playPTT!.toStringAsFixed(4)}',
        style: const TextStyle(
          color: ImageGeneratorConfig.pttBlue,
          fontSize: ImageGeneratorConfig.cardInfo,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x + ImageGeneratorConfig.cardWidth - 15 - textPainter.width,
          infoY,
        ),
      );
    }

    // 目标分数
    final targetScore =
        calculateTargetScore(cardData.constant, cardData.score, totalPTT);
    if (targetScore != null) {
      final targetText = targetScore.toString().padLeft(8, '0');
      final formattedTarget = '>> ${targetText.substring(0, 2)}\' ${targetText.substring(2, 5)}\' ${targetText.substring(5)}';
      textPainter.text = TextSpan(
        text: formattedTarget,
        style: const TextStyle(
          color: ImageGeneratorConfig.targetScore,
          fontSize: ImageGeneratorConfig.cardTarget,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 15, infoY + 45));
    }
  }

  /// 生成完整的B30/R10图片
  static Future<Uint8List> generateImage(
    B30R10Data data, {
    Function(String)? onProgress,
  }) async {
    onProgress?.call('正在初始化画布...');
    debugPrint('[ImageGenerator] 开始生成图片: B30=${data.best30.length}, R10=${data.recent10.length}');

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制背景色
    final paint = Paint()..color = ImageGeneratorConfig.background;
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        ImageGeneratorConfig.canvasWidth.toDouble(),
        ImageGeneratorConfig.canvasHeight.toDouble(),
      ),
      paint,
    );

    // 随机选择一个曲绘作为背景
    onProgress?.call('正在加载背景图片...');
    final allSongs = [...data.best30, ...data.recent10];
    ui.Image? backgroundImage;
    if (allSongs.isNotEmpty) {
      // 随机选择一首歌
      final random = Random();
      final randomIndex = random.nextInt(allSongs.length);
      final randomSong = allSongs[randomIndex];
      
      if (randomSong.coverUrl != null) {
        backgroundImage = await loadImageSafe(randomSong.coverUrl);
        if (backgroundImage != null) {
          debugPrint('[ImageGenerator] 背景图片已加载: ${randomSong.songTitle}');
        } else {
          debugPrint('[ImageGenerator] 无法加载曲绘: ${randomSong.songTitle}，使用纯色背景');
        }
      }
    }

    // 如果有背景图，绘制全屏背景
    if (backgroundImage != null) {
      // 计算缩放比例以覆盖整个画布（保持宽高比）
      final scale = (ImageGeneratorConfig.canvasWidth / backgroundImage.width)
          .clamp(
            ImageGeneratorConfig.canvasHeight / backgroundImage.height,
            double.infinity,
          )
          .toDouble();
      
      final scaledWidth = backgroundImage.width * scale;
      final scaledHeight = backgroundImage.height * scale;
      final offsetX = (ImageGeneratorConfig.canvasWidth - scaledWidth) / 2;
      final offsetY = (ImageGeneratorConfig.canvasHeight - scaledHeight) / 2;

      final srcRect = Rect.fromLTWH(
        0,
        0,
        backgroundImage.width.toDouble(),
        backgroundImage.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(
        offsetX,
        offsetY,
        scaledWidth,
        scaledHeight,
      );
      canvas.drawImageRect(backgroundImage, srcRect, dstRect, paint);

      // 添加深色遮罩到整个画布
      final fullRect = Rect.fromLTWH(
        0,
        0,
        ImageGeneratorConfig.canvasWidth.toDouble(),
        ImageGeneratorConfig.canvasHeight.toDouble(),
      );
      paint.color = const Color(0xD914141E); // 0.85 opacity
      canvas.drawRect(fullRect, paint);

      // 绘制顶部模糊区域
      onProgress?.call('正在处理顶部模糊效果...');
      await _drawBlurredHeader(canvas, backgroundImage, offsetX, offsetY, scaledWidth, scaledHeight);
    }

    // 绘制顶部玩家信息
    onProgress?.call('正在绘制玩家信息...');
    await drawHeader(canvas, data.player);

    // 计算卡片位置并绘制
    const totalWidth = ImageGeneratorConfig.cols * ImageGeneratorConfig.cardWidth +
        (ImageGeneratorConfig.cols - 1) * ImageGeneratorConfig.cardMarginX;
    const startX =
        (ImageGeneratorConfig.canvasWidth - totalWidth) / 2;

    final totalPTT = data.player.totalPTT;
    final totalCards = data.best30.length + data.recent10.length;
    int processedCards = 0;

    // 预加载所有曲绘（并发加载以提高速度）
    onProgress?.call('正在预加载曲绘...');
    final coverLoadTasks = <Future<ui.Image?>>[];
    final coverIndexMap = <int, int>{}; // 索引映射
    
    int taskIndex = 0;
    for (int i = 0; i < data.best30.length; i++) {
      if (data.best30[i].coverUrl != null) {
        coverIndexMap[taskIndex] = i;
        coverLoadTasks.add(loadImageSafe(data.best30[i].coverUrl));
        taskIndex++;
      }
    }
    for (int i = 0; i < data.recent10.length; i++) {
      if (data.recent10[i].coverUrl != null) {
        coverIndexMap[taskIndex] = i + 1000; // R10 用1000+偏移
        coverLoadTasks.add(loadImageSafe(data.recent10[i].coverUrl));
        taskIndex++;
      }
    }
    
    final coverImages = await Future.wait(coverLoadTasks);
    final covers = <String, ui.Image>{};
    for (int i = 0; i < coverImages.length; i++) {
      if (coverImages[i] != null) {
        final originalIndex = coverIndexMap[i]!;
        if (originalIndex < 1000) {
          covers[data.best30[originalIndex].songTitle] = coverImages[i]!;
        } else {
          covers[data.recent10[originalIndex - 1000].songTitle] = coverImages[i]!;
        }
      }
    }
    debugPrint('[ImageGenerator] 已加载 ${covers.length}/${taskIndex} 张曲绘');

    // 绘制 Best 30
    for (int i = 0; i < data.best30.length; i++) {
      final row = i ~/ ImageGeneratorConfig.cols;
      final col = i % ImageGeneratorConfig.cols;

      final x = startX +
          col *
              (ImageGeneratorConfig.cardWidth + ImageGeneratorConfig.cardMarginX);
      final y = ImageGeneratorConfig.cardsStartY +
          row *
              (ImageGeneratorConfig.cardHeight +
                  ImageGeneratorConfig.cardMarginY);

      processedCards++;
      onProgress?.call('正在绘制卡片... ($processedCards/$totalCards) - B${i + 1}');

      // 使用预加载的曲绘
      final coverImage = covers[data.best30[i].songTitle];

      await drawCard(
        canvas,
        data.best30[i],
        x.toDouble(),
        y.toDouble(),
        totalPTT,
        isRecent: false,
        coverImage: coverImage,
      );
    }

    // 绘制 Recent 10（从位置30开始）
    for (int i = 0; i < data.recent10.length; i++) {
      final cardIndex = 30 + i;
      final row = cardIndex ~/ ImageGeneratorConfig.cols;
      final col = cardIndex % ImageGeneratorConfig.cols;

      final x = startX +
          col *
              (ImageGeneratorConfig.cardWidth + ImageGeneratorConfig.cardMarginX);
      final y = ImageGeneratorConfig.cardsStartY +
          row *
              (ImageGeneratorConfig.cardHeight +
                  ImageGeneratorConfig.cardMarginY);

      processedCards++;
      onProgress?.call('正在绘制卡片... ($processedCards/$totalCards) - R${i + 1}');

      // 使用预加载的曲绘
      final coverImage = covers[data.recent10[i].songTitle];

      await drawCard(
        canvas,
        data.recent10[i],
        x.toDouble(),
        y.toDouble(),
        totalPTT,
        isRecent: true,
        coverImage: coverImage,
      );
    }

    // 绘制底部文字
    onProgress?.call('正在添加底部信息...');
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = const TextSpan(
      text: 'Generated by Arcaea Online Helper',
      style: TextStyle(
        color: ImageGeneratorConfig.textTertiary,
        fontSize: ImageGeneratorConfig.footer,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (ImageGeneratorConfig.canvasWidth - textPainter.width) / 2,
        ImageGeneratorConfig.canvasHeight - 30 - textPainter.height / 2,
      ),
    );

    // 转换为图片
    onProgress?.call('正在生成最终图片...');
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      ImageGeneratorConfig.canvasWidth,
      ImageGeneratorConfig.canvasHeight,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    onProgress?.call('图片生成完成！');

    return byteData!.buffer.asUint8List();
  }
}
