import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/utils/difficulty_utils.dart';
import 'data_update_service.dart';

/// 提供歌曲定数查询能力
class SongDataService {
  Map<String, dynamic>? _chartConstants;
  List<dynamic>? _songs;
  List<dynamic>? _chartData;
  final Map<String, String> _titleToSongId = {};
  final Map<String, String> _normalizedTitleToId = {};
  final Map<String, String> _songIdToPack = {};
  bool _isLoaded = false;
  final DataUpdateService _dataUpdateService = DataUpdateService();

  bool get isLoaded => _isLoaded;

  /// 确保数据已加载
  Future<void> ensureLoaded() async {
    if (_isLoaded) return;

    // 优先从本地更新的数据加载，如果没有则从assets加载
    String chartJson;
    String songlistJson;
    String chartDataJson;

    final localChartConstant = await _dataUpdateService.getLocalData('ChartConstant.json');
    chartJson = localChartConstant ?? await rootBundle.loadString(AppConstants.chartConstantPath);
    _chartConstants = jsonDecode(chartJson) as Map<String, dynamic>;

    final localSonglist = await _dataUpdateService.getLocalData('Songlist.json');
    songlistJson = localSonglist ?? await rootBundle.loadString(AppConstants.songlistPath);
    final decodedSonglist = jsonDecode(songlistJson) as Map<String, dynamic>;
    _songs = decodedSonglist['songs'] as List<dynamic>? ?? [];

    // 加载 chart-data.json 以获取曲包信息
    final localChartData =
        await _dataUpdateService.getLocalData('chart-data.json');
    chartDataJson = localChartData ??
        await rootBundle.loadString('assets/data/chart-data.json');
    _chartData = jsonDecode(chartDataJson) as List<dynamic>? ?? [];

    _buildTitleIndex();
    _buildSongPackIndex();
    _isLoaded = true;
  }

  void _buildTitleIndex() {
    if (_songs == null) return;

    for (final rawSong in _songs!) {
      if (rawSong is! Map<String, dynamic>) continue;
      final songId = rawSong['id'] as String?;
      if (songId == null || songId.isEmpty) continue;

      // 添加 title_localized 中的所有标题
      final localized = rawSong['title_localized'];
      if (localized is Map) {
        for (final value in localized.values) {
          if (value is String) {
            _addTitleMapping(value, songId);
          }
        }
      }

      // 添加 search_title 中的所有搜索标题
      final searchTitle = rawSong['search_title'];
      if (searchTitle is Map) {
        for (final entry in searchTitle.values) {
          if (entry is String) {
            _addTitleMapping(entry, songId);
          } else if (entry is List) {
            for (final term in entry) {
              if (term is String) {
                _addTitleMapping(term, songId);
              }
            }
          }
        }
      }

      // 添加歌曲 ID 本身
      _addTitleMapping(songId, songId);
      
      // 尝试添加 remote_title（如果存在）
      final remoteTitle = rawSong['remote_title'];
      if (remoteTitle is Map) {
        for (final value in remoteTitle.values) {
          if (value is String) {
            _addTitleMapping(value, songId);
          }
        }
      }
    }
  }

  void _buildSongPackIndex() {
    _songIdToPack.clear();
    if (_chartData == null) return;

    for (final song in _chartData!) {
      if (song is! Map<String, dynamic>) continue;
      final songId = song['id'] as String?;
      final pack = song['pack'] as String?;
      if (songId == null || songId.isEmpty || pack == null || pack.isEmpty) {
        continue;
      }
      _songIdToPack[songId] = pack;
    }
  }

  void _addTitleMapping(String? text, String songId) {
    if (text == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final lower = trimmed.toLowerCase();
    _titleToSongId.putIfAbsent(lower, () => songId);

    final normalized = _normalizeTitle(lower);
    if (normalized.isNotEmpty) {
      _normalizedTitleToId.putIfAbsent(normalized, () => songId);
    }
  }

  String _normalizeTitle(String value) {
    final sanitized = value.replaceAll(
      RegExp(r'[^\w\s\u3040-\u30ff\u4e00-\u9fa5]'),
      '',
    );
    return sanitized.replaceAll(RegExp(r'\s+'), '');
  }

  String? _findSongId(String title) {
    if (!_isLoaded) return null;
    final normalizedInput = title.trim().toLowerCase();

    // 精确匹配
    if (_titleToSongId.containsKey(normalizedInput)) {
      return _titleToSongId[normalizedInput];
    }

    // 规范化匹配（去除特殊字符后匹配）
    final simplified = _normalizeTitle(normalizedInput);
    if (simplified.isNotEmpty && _normalizedTitleToId.containsKey(simplified)) {
      return _normalizedTitleToId[simplified];
    }

    // 移除模糊匹配，因为它会导致错误匹配
    // 例如 "Last | Moment" 被错误匹配到 "last"
    
    return null;
  }

  /// 通过歌曲名与难度获取定数
  double? getConstant(String songTitle, String difficulty) {
    if (!_isLoaded) return null;
    final songId = _findSongId(songTitle);
    if (songId == null) {
      // 找不到歌曲，可能是标题匹配问题
      return null;
    }

    final constants = _chartConstants?[songId];
    if (constants is! List) {
      return null;
    }

    final diffIndex = _parseDifficultyIndex(difficulty);
    if (diffIndex < 0 || diffIndex >= constants.length) {
      return null;
    }

    final entry = constants[diffIndex];
    if (entry is Map<String, dynamic> && entry['constant'] != null) {
      return (entry['constant'] as num).toDouble();
    }

    // 该难度没有定数（entry 为 null），这是正常情况
    // 不是所有歌曲都有 ETR/BYD 难度
    return null;
  }

  /// 检查歌曲是否有指定难度
  bool hasDifficulty(String songTitle, String difficulty) {
    if (!_isLoaded) return false;
    final songId = _findSongId(songTitle);
    if (songId == null) return false;

    final constants = _chartConstants?[songId];
    if (constants is! List) return false;

    final diffIndex = _parseDifficultyIndex(difficulty);
    if (diffIndex < 0 || diffIndex >= constants.length) return false;

    final entry = constants[diffIndex];
    return entry != null;
  }

  /// 检查是否能找到歌曲（用于判断是否是标题匹配问题）
  bool canFindSong(String songTitle) {
    if (!_isLoaded) return false;
    return _findSongId(songTitle) != null;
  }

  int _parseDifficultyIndex(String difficulty) {
    final normalized = difficulty.trim().toLowerCase();
    switch (normalized) {
      case 'past':
      case 'pst':
        return 0;
      case 'present':
      case 'prs':
        return 1;
      case 'future':
      case 'ftr':
        return 2;
      case 'beyond':
      case 'byd':
        return 3;  // 修复：BYD 是索引 3
      case 'eternal':
      case 'etr':
        return 4;  // 修复：ETR 是索引 4
      default:
        return -1;
    }
  }

  /// 获取所有可用的曲包列表（去重并排序）
  List<String> getAllPacks() {
    if (!_isLoaded || _chartData == null) return [];
    
    final Set<String> packs = {};
    for (final song in _chartData!) {
      if (song is Map<String, dynamic>) {
        final pack = song['pack'];
        if (pack is String && pack.isNotEmpty) {
          packs.add(pack);
        }
      }
    }
    
    final packList = packs.toList();
    packList.sort();
    return packList;
  }

  /// 通过歌曲标题获取曲包名称
  String? getPackBySongTitle(String songTitle) {
    if (!_isLoaded || _chartData == null) return null;

    final songId = _findSongId(songTitle);
    if (songId == null) return null;

    // 优先使用预构建索引
    final pack = _songIdToPack[songId];
    if (pack != null) return pack;

    // 兼容旧数据：回退到遍历查找
    for (final song in _chartData!) {
      if (song is! Map<String, dynamic>) continue;
      if (song['id'] == songId) {
        final value = song['pack'];
        if (value is String && value.isNotEmpty) {
          _songIdToPack[songId] = value;
          return value;
        }
      }
    }

    return null;
  }

  /// 获取所有谱面定数信息（用于定数表）
  ///
  /// 每个条目代表一首歌的一个难度及其定数
  List<SongChartInfo> getAllChartInfos() {
    if (!_isLoaded || _chartConstants == null || _songs == null) return [];

    // 建立歌曲元数据索引
    final Map<String, Map<String, dynamic>> songMetaById = {};
    for (final rawSong in _songs!) {
      if (rawSong is! Map<String, dynamic>) continue;
      final songId = rawSong['id'] as String?;
      if (songId == null || songId.isEmpty) continue;
      songMetaById[songId] = rawSong;
    }

    final List<SongChartInfo> result = [];

    _chartConstants!.forEach((songId, value) {
      if (value is! List) return;

      final meta = songMetaById[songId];
      final title = _getDisplayTitle(meta);
      final artist = _getArtist(meta);
      final pack = _songIdToPack[songId] ?? '';

      for (var i = 0; i < value.length; i++) {
        final entry = value[i];
        if (entry is! Map<String, dynamic>) continue;

        final constantValue = entry['constant'];
        if (constantValue == null) continue;

        final constant = (constantValue as num).toDouble();
        final difficulty = _difficultyFromIndex(i);

        result.add(
          SongChartInfo(
            songId: songId,
            title: title,
            artist: artist,
            pack: pack,
            difficulty: difficulty,
            constant: constant,
          ),
        );
      }
    });

    // 默认排序：按曲包 -> 曲名 -> 难度
    result.sort((a, b) {
      final packCmp = a.pack.compareTo(b.pack);
      if (packCmp != 0) return packCmp;

      final titleCmp = a.title.compareTo(b.title);
      if (titleCmp != 0) return titleCmp;

      final aIdx = DifficultyUtils.parseDifficultyIndex(a.difficulty);
      final bIdx = DifficultyUtils.parseDifficultyIndex(b.difficulty);
      return aIdx.compareTo(bIdx);
    });

    return result;
  }

  String _getDisplayTitle(Map<String, dynamic>? rawSong) {
    if (rawSong == null) return '';

    final localized = rawSong['title_localized'];
    if (localized is Map) {
      // 优先简中 -> 日文 -> 英文
      final preferredKeys = ['zh-Hans', 'ja', 'en'];
      for (final key in preferredKeys) {
        final value = localized[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      // 退而求其次：任意一个非空字符串
      for (final value in localized.values) {
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    final title = rawSong['title'];
    if (title is String && title.trim().isNotEmpty) {
      return title.trim();
    }

    return '';
  }

  String _getArtist(Map<String, dynamic>? rawSong) {
    if (rawSong == null) return '';
    final artist = rawSong['artist'];
    if (artist is String && artist.trim().isNotEmpty) {
      return artist.trim();
    }
    return '';
  }

  String _difficultyFromIndex(int index) {
    switch (index) {
      case 0:
        return 'PST';
      case 1:
        return 'PRS';
      case 2:
        return 'FTR';
      case 3:
        return 'BYD';
      case 4:
        return 'ETR';
      default:
        return index.toString();
    }
  }
}

/// 歌曲谱面定数信息（用于定数表显示）
class SongChartInfo {
  final String songId;
  final String title;
  final String artist;
  final String pack;
  final String difficulty;
  final double constant;

  const SongChartInfo({
    required this.songId,
    required this.title,
    required this.artist,
    required this.pack,
    required this.difficulty,
    required this.constant,
  });
}
