import '../../core/core.dart';
import '../../models/b30r10_data.dart';
import '../../models/score_data.dart';
import '../../services/image_generation_manager.dart';
import '../../services/score_storage_service.dart';
import '../../services/song_data_service.dart';

/// PTT 页面控制器
/// 管理页面状态和业务逻辑
class PTTPageController {
  final ImageGenerationManager imageManager;
  final ScoreStorageService storageService;
  final SongDataService songDataService;
  
  PTTPageController({
    required this.imageManager,
    ScoreStorageService? storageService,
    SongDataService? songDataService,
  })  : storageService = storageService ?? ScoreStorageService(),
        songDataService = songDataService ?? SongDataService();

  B30R10Data? get data => imageManager.cachedData;

  /// 对比 PTT 变化
  Future<double?> comparePTT() async {
    final currentPTT = data?.player.totalPTT;
    if (currentPTT == null) return null;

    final previousPTT = await storageService.getPreviousPTT();
    if (previousPTT == null) return null;

    final difference = currentPTT - previousPTT;
    return difference.abs() < 0.0001 ? null : difference;
  }

  /// 保存当前 PTT 作为上一次的 PTT
  Future<void> saveCurrentPTT() async {
    final currentPTT = data?.player.totalPTT;
    if (currentPTT != null) {
      await storageService.savePreviousPTT(currentPTT);
    }
  }

  /// 加载额外的 Best 曲目
  Future<ExtraSongsResult> loadExtraBestSongs(int extraCount) async {
    if (data == null || extraCount <= 0) {
      return ExtraSongsResult(songs: [], message: null);
    }

    try {
      final scores = await storageService.loadScores();
      if (scores.isEmpty) {
        return ExtraSongsResult(
          songs: [],
          message: '需要先在成绩列表页拉取成绩',
        );
      }

      await songDataService.ensureLoaded();
      final extras = _buildExtraSongsFromScores(scores, data!, extraCount);

      String? message;
      if (extras.isEmpty) {
        message = '没有找到更多的高分成绩';
      } else if (extras.length < extraCount) {
        message = '仅找到 ${extras.length} 首符合条件的曲目';
      }

      return ExtraSongsResult(songs: extras, message: message);
    } catch (_) {
      return ExtraSongsResult(
        songs: [],
        message: '加载额外曲目失败',
      );
    }
  }

  List<SongCardData> _buildExtraSongsFromScores(
    List<ScoreData> scores,
    B30R10Data data,
    int extraCount,
  ) {
    // 构建已知歌曲的查找表
    final Map<String, SongCardData> knownSongs = {};
    for (final song in data.best30) {
      knownSongs[DifficultyUtils.buildSongKey(song.songTitle, song.difficulty)] = song;
    }
    for (final song in data.recent10) {
      final key = DifficultyUtils.buildSongKey(song.songTitle, song.difficulty);
      knownSongs.putIfAbsent(key, () => song);
    }

    // B30 中已有的歌曲（需要排除）
    final Set<String> excludedKeys = data.best30
        .map((song) => DifficultyUtils.buildSongKey(song.songTitle, song.difficulty))
        .toSet();

    // 收集候选曲目
    final List<_ExtraSongCandidate> candidates = [];
    for (final score in scores) {
      final key = DifficultyUtils.buildSongKey(score.songTitle, score.difficulty);
      if (excludedKeys.contains(key)) continue;

      final reference = knownSongs[key];
      final constant = reference?.constant ??
          songDataService.getConstant(score.songTitle, score.difficulty);
      if (constant == null) continue;

      final playPTT = reference?.playPTT ?? 
          PTTCalculator.calculatePlayPTT(score.score, constant);
      if (playPTT == null) continue;

      candidates.add(_ExtraSongCandidate(
        score: score,
        constant: constant,
        playPTT: playPTT,
      ));
    }

    // 按 PTT 排序并取前 N 个
    candidates.sort((a, b) => b.playPTT.compareTo(a.playPTT));
    final selected = candidates.take(extraCount).toList();

    // 构建结果
    final extras = <SongCardData>[];
    var rank = data.best30.length + 1;

    for (final candidate in selected) {
      extras.add(SongCardData(
        songTitle: candidate.score.songTitle,
        difficulty: candidate.score.difficulty.toUpperCase(),
        difficultyIndex: DifficultyUtils.parseDifficultyIndex(candidate.score.difficulty),
        score: candidate.score.score,
        constant: candidate.constant,
        playPTT: candidate.playPTT,
        coverUrl: candidate.score.albumArtUrl,
        rank: rank++,
      ));
    }

    return extras;
  }

  /// 计算目标分数
  int? calculateTargetScore(SongCardData song, double? totalPTT) {
    if (song.constant == null || totalPTT == null) return null;
    if (song.score >= 10000000) return null;

    return PTTCalculator.calculateTargetScore(
      constant: song.constant!,
      currentScore: song.score,
      totalPTT: totalPTT,
    );
  }
}

/// 额外曲目加载结果
class ExtraSongsResult {
  final List<SongCardData> songs;
  final String? message;

  ExtraSongsResult({required this.songs, this.message});
}

class _ExtraSongCandidate {
  final ScoreData score;
  final double constant;
  final double playPTT;

  _ExtraSongCandidate({
    required this.score,
    required this.constant,
    required this.playPTT,
  });
}
