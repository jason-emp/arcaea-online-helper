import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/utils/ptt_calculator.dart';
import '../models/b30r10_data.dart';
import 'song_data_service.dart';

/// 最小化数据提取脚本
/// 仅在页面中执行一次，提取原始 DOM 数据后返回，不在 WebView 注入任何业务逻辑
const String _extractRawDataScript = r'''
(function() {
  const diffMap = {'PST':0,'PAST':0,'PRS':1,'PRESENT':1,'FTR':2,'FUTURE':2,'BYD':3,'BEYOND':3,'ETR':4,'ETERNAL':4};
  const diffNames = ['PST','PRS','FTR','BYD','ETR'];
  
  // 寻找包含分数的所有元素
  const allCards = document.querySelectorAll('.card, [class*="card"]');
  let songCardElements = [];
  for (const el of allCards) {
    const t = el.innerText || '';
    const hasScore = /\d{1,3}(,\d{3}){2}/.test(t) || /\d{7,8}/.test(t);
    const hasDiff = /FTR|BYD|PRS|PST|ETR|FUTURE|BEYOND|PRESENT|PAST|ETERNAL/i.test(t);
    if (hasScore && hasDiff && t.length > 20) {
      songCardElements.push(el);
    }
  }
  
  function getDifficulty(el) {
    const labels = el.querySelectorAll('span.label, .label, span');
    for (const l of labels) {
      const t = (l.textContent||'').trim().toUpperCase();
      if (diffMap[t] !== undefined) return diffMap[t];
    }
    // 回退：检查 class 名称中的难度
    for (const child of el.querySelectorAll('*')) {
      const cls = (child.className || '').toUpperCase();
      for (const d of Object.keys(diffMap)) {
        if (cls.includes(d)) return diffMap[d];
      }
    }
    return -1;
  }
  
  function getTitleAndScore(el) {
    let title=null, score=null;
    // 扩展标题选择器
    for (const s of el.querySelectorAll('span.no-overflow, .title span, .title .no-overflow, [class*="title"], .song-title, .name')) {
      const t = (s.textContent||'').trim();
      if (t.length>0 && t.length<60 && !/^\d+$/.test(t) && !t.includes('潜力值')) {
        title = t.replace(/\s*\([\d.]+\)\s*$/,'').trim();
        break;
      }
    }
    // 扩展分数选择器
    const scoreEls = el.querySelectorAll('.ex-main, [class*="ex-main"], .score, [class*="score"]');
    for (const e of scoreEls) {
      const m = (e.textContent||'').match(/(\d{1,3}(,\d{3})*|\d{7,8})/);
      if (m) {
        const n = parseInt(m[0].replace(/,/g,''),10);
        if (n>=5000000 && n<=10002000) { score = n; break; }
      }
    }
    if (!score) {
      const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
      let node;
      while (node = walker.nextNode()) {
        const t = (node.textContent||'').trim();
        if (t.includes('/')||t.includes(':')) continue;
        const m = t.match(/(\d{1,3}(,\d{3})*|\d{7,8})/);
        if (m) {
          const n = parseInt(m[0].replace(/,/g,''),10);
          if (n>=5000000 && n<=10002000) { score = n; break; }
        }
      }
    }
    // 如果标题还没找到，尝试从整个卡片文本中提取
    if (!title) {
      const allText = (el.innerText || '').split('\n').map(s => s.trim()).filter(s => s.length > 0);
      for (const line of allText) {
        if (line.length > 2 && line.length < 60 && !/^\d+$/.test(line) && 
            !/(FTR|BYD|PRS|PST|ETR|FUTURE|BEYOND|PRESENT|PAST|ETERNAL)/i.test(line) &&
            !/\d{7,8}/.test(line) && !/\d{1,3}(,\d{3}){2}/.test(line) &&
            !line.includes('潜力值')) {
          title = line;
          break;
        }
      }
    }
    return {title, score};
  }
  
  function getCoverUrl(el) {
    for (const e of el.querySelectorAll('*')) {
      const bg = window.getComputedStyle(e).backgroundImage;
      if (bg && bg !== 'none') {
        const u = bg.match(/url\(["']?([^"']+)["']?\)/);
        if (u && u[1] && !u[1].startsWith('data:image/svg') && 
            (u[1].includes('.jpg')||u[1].includes('.png')||u[1].includes('.webp'))) return u[1];
      }
    }
    for (const img of el.querySelectorAll('img')) {
      if (img.src && !img.src.startsWith('data:image/svg') && 
          (img.src.includes('.jpg')||img.src.includes('.png')||img.src.includes('.webp'))) return img.src;
    }
    return null;
  }
  
  function isSongCard(el) {
    const t = el.innerText || '';
    const hasDiff = /FTR|BYD|PRS|PST|ETR|FUTURE|BEYOND|PRESENT|PAST|ETERNAL/i.test(t);
    const hasScore = /\d{1,3}(,\d{3}){2}/.test(t) || /\d{7,8}/.test(t);
    const isPtt = (t.includes('潜力值')||t.includes('Potential')) && (t.includes('+')||t.includes('-'));
    return hasDiff && hasScore && t.length>20 && !isPtt;
  }
  
  const cards = [];
  
  // 策略1: 从 card-list 容器中查找
  const lists = document.querySelectorAll('.card-list, [class*="card-list"]');
  for (const list of lists) {
    let elms = list.querySelectorAll('.card');
    if (elms.length === 0) {
      elms = list.children;
    }
    for (const el of elms) {
      if (!isSongCard(el)) continue;
      const {title, score} = getTitleAndScore(el);
      const diff = getDifficulty(el);
      if (!title || score==null || diff<0) continue;
      cards.push({title, score, difficulty: diff, coverUrl: getCoverUrl(el)});
    }
  }
  
  // 策略2: 如果策略1 没找到，直接从之前发现的 songCardElements 中提取
  if (cards.length === 0 && songCardElements.length > 0) {
    // 去重：用最内层的包含分数+难度的元素
    const used = new Set();
    for (const el of songCardElements) {
      // 跳过太大的容器（可能是整个列表）
      if ((el.innerText||'').length > 2000) continue;
      // 检查是否被其他已选中的元素包含
      let dominated = false;
      for (const other of used) {
        if (other.contains(el) || el.contains(other)) { dominated = true; break; }
      }
      if (dominated) continue;
      used.add(el);
      
      const {title, score} = getTitleAndScore(el);
      const diff = getDifficulty(el);
      if (!title || score==null || diff<0) continue;
      cards.push({title, score, difficulty: diff, coverUrl: getCoverUrl(el)});
    }
  }
  
  let username = 'Player';
  const unEl = document.querySelector('.username, [class*="username"]');
  if (unEl) username = (unEl.textContent||'').trim();
  
  return JSON.stringify({cards, username});
})();
''';

/// B30/R10 页面数据提取器
/// 通过最小化 JS 从 WebView 获取原始 DOM 数据，在 Flutter 侧完成解析与计算
class B30R10PageExtractor {
  final SongDataService _songDataService = SongDataService();
  final void Function(String message)? onDebugMessage;

  B30R10PageExtractor({this.onDebugMessage});

  void _log(String msg) => onDebugMessage?.call(msg);

  /// 从 WebView 页面提取 B30/R10 数据
  /// 使用单次 evaluateJavascript 获取原始数据，其余处理在 Flutter 完成
  Future<B30R10Data?> extractFromPage(InAppWebViewController controller) async {
    try {
      _log('开始从页面提取原始数据（无脚本注入）');

      final result = await controller.evaluateJavascript(source: _extractRawDataScript);
      
      if (result == null) {
        _log('提取返回空');
        return null;
      }

      final jsonStr = result is String ? result : jsonEncode(result);
      final raw = jsonDecode(jsonStr) as Map<String, dynamic>;
      final cardsList = raw['cards'] as List<dynamic>? ?? [];
      final username = raw['username'] as String? ?? 'Player';

      if (cardsList.isEmpty) {
        _log('未找到有效卡片数据');
        return null;
      }

      await _songDataService.ensureLoaded();

      final best30List = <SongCardData>[];
      final recent10List = <SongCardData>[];

      const diffNames = ['PST', 'PRS', 'FTR', 'BYD', 'ETR'];

      for (var i = 0; i < cardsList.length; i++) {
        if (best30List.length >= 30 && recent10List.length >= 10) break;

        final c = cardsList[i] as Map<String, dynamic>;
        final title = c['title'] as String? ?? '';
        final score = _toInt(c['score']);
        final diffIndex = _toInt(c['difficulty']);
        final coverUrl = c['coverUrl'] as String?;

        if (title.isEmpty || score <= 0 || diffIndex < 0 || diffIndex > 4) continue;

        final diffName = diffNames[diffIndex];
        final constant = _songDataService.getConstant(title, diffName);
        final playPTT = PTTCalculator.calculatePlayPTT(score, constant);

        if (best30List.length < 30) {
          best30List.add(SongCardData(
            songTitle: title,
            difficulty: diffName,
            difficultyIndex: diffIndex,
            score: score,
            constant: constant,
            playPTT: playPTT,
            coverUrl: coverUrl,
            rank: best30List.length + 1,
          ));
        } else if (recent10List.length < 10) {
          recent10List.add(SongCardData(
            songTitle: title,
            difficulty: diffName,
            difficultyIndex: diffIndex,
            score: score,
            constant: constant,
            playPTT: playPTT,
            coverUrl: coverUrl,
            rank: recent10List.length + 1,
          ));
        }
      }

      double? best30Avg;
      double? recent10Avg;
      double? totalPTT;

      if (best30List.isNotEmpty) {
        final valid = best30List.where((c) => c.playPTT != null).toList();
        if (valid.isNotEmpty) {
          best30Avg = valid.map((c) => c.playPTT!).reduce((a, b) => a + b) / valid.length;
        }
      }
      if (recent10List.isNotEmpty) {
        final valid = recent10List.where((c) => c.playPTT != null).toList();
        if (valid.isNotEmpty) {
          recent10Avg = valid.map((c) => c.playPTT!).reduce((a, b) => a + b) / valid.length;
        }
      }
      if (best30Avg != null && recent10Avg != null) {
        totalPTT = (best30Avg * 30 + recent10Avg * 10) / 40;
      }

      final data = B30R10Data(
        player: PlayerData(
          username: username,
          totalPTT: totalPTT,
          best30Avg: best30Avg,
          recent10Avg: recent10Avg,
          exportDate: DateTime.now(),
        ),
        best30: best30List,
        recent10: recent10List,
      );

      _log('提取完成: ${data.player.username}, B30=${best30List.length}, R10=${recent10List.length}');
      return data;
    } catch (e, st) {
      _log('提取失败: $e\n$st');
      return null;
    }
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
