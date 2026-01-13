import 'dart:convert';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import 'data_update_service.dart';

/// 提供歌曲定数查询能力
class SongDataService {
  Map<String, dynamic>? _chartConstants;
  List<dynamic>? _songs;
  List<dynamic>? _chartData;
  final Map<String, String> _titleToSongId = {};
  final Map<String, String> _normalizedTitleToId = {};
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
    final localChartData = await _dataUpdateService.getLocalData('chart-data.json');
    chartDataJson = localChartData ?? await rootBundle.loadString('assets/data/chart-data.json');
    _chartData = jsonDecode(chartDataJson) as List<dynamic>? ?? [];

    _buildTitleIndex();
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
    
    for (final song in _chartData!) {
      if (song is Map<String, dynamic>) {
        if (song['id'] == songId) {
          return song['pack'] as String?;
        }
      }
    }
    
    return null;
  }
}
