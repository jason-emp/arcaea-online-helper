import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/partner_data.dart';
import '../services/partner_fetch_service.dart';

/// 搭档页面 - 显示搭档列表和数据
class PartnerPage extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  const PartnerPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<PartnerPage> createState() => _PartnerPageState();
}

enum SortType {
  none,
  levelDesc,
  levelAsc,
  fragDesc,
  fragAsc,
  stepDesc,
  stepAsc,
  overDesc,
  overAsc,
  lostChapterCustom,
  fallChapterCustom,
}

enum FallChapterSortMethod {
  overPlusHalfStep, // 进度 = 超量 + 步数/2
  frag, // 进度 = 残数
  levelFormula, // 进度 = max(1.0, 2.0 - 0.1 x 等级)
  complexFormula, // 进度 = 超量 - ||超量-残数|-|超量-步数||
}

class _PartnerPageState extends State<PartnerPage> {
  final PartnerFetchService _fetchService = PartnerFetchService();
  final ScrollController _scrollController = ScrollController();

  List<PartnerData> _partners = [];
  bool _isFetching = false;
  double _progress = 0.0;
  String? _errorMessage;
  SortType _currentSort = SortType.none;

  // 失落章节排序相关
  Map<String, double> _affinityCoefficients = {};
  Map<String, double> _lostChapterScores = {};

  // 陷落章节排序相关
  FallChapterSortMethod? _fallChapterMethod;
  Map<String, double> _fallChapterScores = {};

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _loadCachedData();
  }

  void _setupListeners() {
    _fetchService.partnerStream.listen((partners) {
      if (mounted) {
        setState(() {
          _partners = partners;
          _applySorting();
        });
      }
    });

    _fetchService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          if (progress >= 0 && progress <= 1) {
            _progress = progress;
          }
        });
      }
    });

    _fetchService.errorStream.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
        setState(() {
          _isFetching = false;
          _errorMessage = error;
        });
      }
    });
  }

  Future<void> _loadCachedData() async {
    final cachedPartners = await _fetchService.loadCachedPartners();
    if (cachedPartners.isNotEmpty && mounted) {
      setState(() {
        _partners = cachedPartners;
        _applySorting();
      });
    }
  }

  /// 清除搭档缓存数据
  Future<void> _clearPartnerData() async {
    await _fetchService.clearPartnerData();
    if (mounted) {
      setState(() {
        _partners = [];
        _affinityCoefficients.clear();
        _lostChapterScores.clear();
        _fallChapterScores.clear();
        _fallChapterMethod = null;
        _currentSort = SortType.none;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('搭档数据已清除'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 显示清除数据确认对话框
  void _showClearDataConfirmDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
        title: const Text('确认清除搭档数据'),
        content: const Text(
          '此操作将永久删除：\n\n'
          '• 所有搭档信息\n'
          '• 失落章节排序设置\n'
          '• 陷落章节排序设置\n\n'
          '清除后需要重新拉取数据，此操作无法撤销，确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _clearPartnerData();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }

  void _applySorting() {
    switch (_currentSort) {
      case SortType.levelDesc:
        _partners.sort((a, b) => b.level.compareTo(a.level));
        break;
      case SortType.levelAsc:
        _partners.sort((a, b) => a.level.compareTo(b.level));
        break;
      case SortType.fragDesc:
        _partners.sort((a, b) => b.frag.compareTo(a.frag));
        break;
      case SortType.fragAsc:
        _partners.sort((a, b) => a.frag.compareTo(b.frag));
        break;
      case SortType.stepDesc:
        _partners.sort((a, b) => b.step.compareTo(a.step));
        break;
      case SortType.stepAsc:
        _partners.sort((a, b) => a.step.compareTo(b.step));
        break;
      case SortType.overDesc:
        _partners.sort((a, b) => b.overdrive.compareTo(a.overdrive));
        break;
      case SortType.overAsc:
        _partners.sort((a, b) => a.overdrive.compareTo(b.overdrive));
        break;
      case SortType.lostChapterCustom:
        _applyLostChapterSorting();
        break;
      case SortType.fallChapterCustom:
        _applyFallChapterSorting();
        break;
      case SortType.none:
        // 保持原顺序
        break;
    }
  }

  /// 显示设置头像对话框
  void _showSetAvatarDialog(PartnerData partner) {
    final isCurrentAvatar = widget.settings.selectedPartnerIconUrl == partner.iconUrl;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            ClipOval(
              child: Image.network(
                partner.iconUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[300],
                    child: const Icon(Icons.person),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                partner.name,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCurrentAvatar 
                  ? '此搭档已设置为 PTT 页面的头像'
                  : '将此搭档设置为 PTT 页面的头像？',
              style: const TextStyle(fontSize: 14),
            ),
            if (!isCurrentAvatar) ...[
              const SizedBox(height: 16),
              Text(
                '设置后，PTT 页面的玩家信息卡片将显示该搭档的头像。',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        actions: [
          if (isCurrentAvatar)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _clearAvatar();
              },
              child: const Text('取消设置'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
          if (!isCurrentAvatar)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _setAvatar(partner);
              },
              child: const Text('设置'),
            ),
        ],
      ),
    );
  }

  /// 设置头像
  void _setAvatar(PartnerData partner) {
    final newSettings = widget.settings.copyWith(
      selectedPartnerIconUrl: partner.iconUrl,
    );
    widget.onSettingsChanged(newSettings);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${partner.name} 设置为 PTT 头像'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 清除头像
  void _clearAvatar() {
    // 创建一个新的settings对象，显式设置selectedPartnerIconUrl为null
    final newSettings = AppSettings(
      showCharts: widget.settings.showCharts,
      showConstant: widget.settings.showConstant,
      showPTT: widget.settings.showPTT,
      showTargetScore: widget.settings.showTargetScore,
      showDownloadButtons: widget.settings.showDownloadButtons,
      extraBestSongsCount: widget.settings.extraBestSongsCount,
      selectedPartnerIconUrl: null,
    );
    widget.onSettingsChanged(newSettings);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已取消 PTT 头像设置'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _changeSortType(SortType? newSort) {
    if (newSort != null) {
      setState(() {
        _currentSort = newSort;
        _applySorting();
      });
    }
  }

  String _getSortDisplayName(SortType sort) {
    switch (sort) {
      case SortType.none:
        return '默认排序';
      case SortType.levelDesc:
        return '等级 (高→低)';
      case SortType.levelAsc:
        return '等级 (低→高)';
      case SortType.fragDesc:
        return 'Frag (高→低)';
      case SortType.fragAsc:
        return 'Frag (低→高)';
      case SortType.stepDesc:
        return 'Step (高→低)';
      case SortType.stepAsc:
        return 'Step (低→高)';
      case SortType.overDesc:
        return 'Over (高→低)';
      case SortType.overAsc:
        return 'Over (低→高)';
      case SortType.lostChapterCustom:
        return '失落章节排序';
      case SortType.fallChapterCustom:
        return '陷落章节排序';
    }
  }

  Future<void> _startFetching() async {
    setState(() {
      _isFetching = true;
      _partners = [];
      _progress = 0.0;
      _errorMessage = null;
    });

    try {
      await _fetchService.startFetching();
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  void _stopFetching() {
    _fetchService.stopFetching();
    setState(() {
      _isFetching = false;
    });
  }

  // 检查是否需要额外的1/3系数
  bool _needsExtraDivision(String partnerName) {
    const specialPartners = [
      '潘多拉涅墨西斯[MTA-XXX]',
      '奈美[暮光]',
      '不来方永爱',
      '对立[Tempest]',
      'DORO*C',
      '光[Fatalis]',
    ];

    // 标准化名称：移除所有空格进行比较
    String normalizedInput = partnerName.replaceAll(' ', '');

    for (var special in specialPartners) {
      String normalizedSpecial = special.replaceAll(' ', '');
      if (normalizedInput == normalizedSpecial) {
        return true;
      }
    }

    return false;
  }

  // 应用失落章节排序
  void _applyLostChapterSorting() {
    _lostChapterScores.clear();

    for (var partner in _partners) {
      double affinity = _affinityCoefficients[partner.name] ?? 1.0;
      double score = partner.overdrive * affinity;

      // 特殊角色额外乘以1/3
      if (_needsExtraDivision(partner.name)) {
        score = score / 3;
      }

      _lostChapterScores[partner.name] = score;
    }

    _partners.sort((a, b) {
      double scoreA = _lostChapterScores[a.name] ?? 0;
      double scoreB = _lostChapterScores[b.name] ?? 0;
      return scoreB.compareTo(scoreA);
    });
  }

  // 清除失落章节排序
  void _clearLostChapterSort() {
    setState(() {
      _affinityCoefficients.clear();
      _lostChapterScores.clear();
      _currentSort = SortType.none;
      _applySorting();
    });
  }

  // 获取陷落章节排序方法的显示名称
  String _getFallChapterMethodName(FallChapterSortMethod method) {
    switch (method) {
      case FallChapterSortMethod.overPlusHalfStep:
        return '进度 = 超量 + 步数/2';
      case FallChapterSortMethod.frag:
        return '进度 = 残数';
      case FallChapterSortMethod.levelFormula:
        return '进度 = max(1.0, 2.0 - 0.1×等级)';
      case FallChapterSortMethod.complexFormula:
        return '进度 = 超量 - ||超量-残数|-|超量-步数||';
    }
  }

  // 根据选定的方法计算进度值
  double _calculateProgress(PartnerData partner, FallChapterSortMethod method) {
    switch (method) {
      case FallChapterSortMethod.overPlusHalfStep:
        // 进度 = 超量 + 步数/2
        return partner.overdrive + partner.step / 2.0;

      case FallChapterSortMethod.frag:
        // 进度 = 残数
        return partner.frag.toDouble();

      case FallChapterSortMethod.levelFormula:
        // 进度 = max(1.0, 2.0 - 0.1 x 等级)
        double value = 2.0 - 0.1 * partner.level;
        return value > 1.0 ? value : 1.0;

      case FallChapterSortMethod.complexFormula:
        // 进度 = 超量 - ||超量-残数|-|超量-步数||
        double over = partner.overdrive.toDouble();
        double frag = partner.frag.toDouble();
        double step = partner.step.toDouble();

        double diff1 = (over - frag).abs();
        double diff2 = (over - step).abs();
        double innerAbs = (diff1 - diff2).abs();

        return over - innerAbs;
    }
  }

  // 应用陷落章节排序
  void _applyFallChapterSorting() {
    if (_fallChapterMethod == null) return;

    _fallChapterScores.clear();

    for (var partner in _partners) {
      double score = _calculateProgress(partner, _fallChapterMethod!);
      _fallChapterScores[partner.name] = score;
    }

    // 从大到小排序
    _partners.sort((a, b) {
      double scoreA = _fallChapterScores[a.name] ?? 0;
      double scoreB = _fallChapterScores[b.name] ?? 0;
      return scoreB.compareTo(scoreA);
    });
  }

  // 清除陷落章节排序
  void _clearFallChapterSort() {
    setState(() {
      _fallChapterMethod = null;
      _fallChapterScores.clear();
      _currentSort = SortType.none;
      _applySorting();
    });
  }

  // 显示高级排序选项对话框
  Future<void> _showAdvancedSortDialog() async {
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('高级排序'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('失落章节排序'),
                subtitle: const Text('设置相性契合系数'),
                onTap: () {
                  Navigator.of(dialogContext).pop('lostChapter');
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_down),
                title: const Text('陷落章节排序'),
                subtitle: const Text('选择排序方式'),
                onTap: () {
                  Navigator.of(dialogContext).pop('fallChapter');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (result == 'lostChapter' && mounted) {
      _showLostChapterSortDialog();
    } else if (result == 'fallChapter' && mounted) {
      _showFallChapterSortDialog();
    }
  }

  // 显示失落章节排序设置对话框
  Future<void> _showLostChapterSortDialog() async {
    final tempCoefficients = Map<String, double>.from(_affinityCoefficients);
    final controllers = <String, TextEditingController>{};

    // 初始化文本控制器
    for (var partner in _partners) {
      final currentValue = tempCoefficients[partner.name] ?? 1.0;
      controllers[partner.name] = TextEditingController(
        text: currentValue != 1.0 ? currentValue.toString() : '',
      );
    }

    if (!mounted) {
      // 清理控制器
      for (var controller in controllers.values) {
        controller.dispose();
      }
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('失落章节排序设置'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _partners.length,
              itemBuilder: (context, index) {
                final partner = _partners[index];
                final needsExtra = _needsExtraDivision(partner.name);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partner.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Over: ${partner.overdrive}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (needsExtra)
                                Text(
                                  '×1/3系数',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: controllers[partner.name],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '相性契合',
                              hintText: '1.0',
                              isDense: true,
                            ),
                            onChanged: (value) {
                              if (value.isEmpty) {
                                tempCoefficients[partner.name] = 1.0;
                              } else {
                                final parsed = double.tryParse(value);
                                if (parsed != null) {
                                  tempCoefficients[partner.name] = parsed;
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('应用'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      setState(() {
        _affinityCoefficients = tempCoefficients;
        _currentSort = SortType.lostChapterCustom;
        _applySorting();
      });
    }

    // 延迟清理控制器，确保对话框动画完成
    Future.delayed(const Duration(milliseconds: 300), () {
      for (var controller in controllers.values) {
        controller.dispose();
      }
    });
  }

  // 显示陷落章节排序设置对话框
  Future<void> _showFallChapterSortDialog() async {
    if (!mounted) return;

    final result = await showDialog<FallChapterSortMethod>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('陷落章节排序'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请选择排序方式（从大到小排序）：', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              ...FallChapterSortMethod.values.map((method) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(_getFallChapterMethodName(method)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(dialogContext).pop(method);
                    },
                  ),
                );
              }).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _fallChapterMethod = result;
        _currentSort = SortType.fallChapterCustom;
        _applySorting();
      });
    }
  }

  @override
  void dispose() {
    _fetchService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('搭档列表'),
            FutureBuilder<DateTime?>(
              future: _fetchService.getLastUpdateTime(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final time = snapshot.data!;
                  final formattedTime =
                      '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                  return Text(
                    '最后更新: $formattedTime',
                    style: const TextStyle(fontSize: 12),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        actions: [
          if (_isFetching)
            IconButton(icon: const Icon(Icons.stop), onPressed: _stopFetching)
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startFetching,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear') {
                _showClearDataConfirmDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 8),
                    Text('清除数据'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isFetching)
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          // 排序选择器
          if (_partners.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        '排序: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: DropdownButton<SortType>(
                          value:
                              (_currentSort == SortType.fallChapterCustom ||
                                  _currentSort == SortType.lostChapterCustom)
                              ? SortType.none
                              : _currentSort,
                          isExpanded: true,
                          onChanged:
                              (_currentSort == SortType.fallChapterCustom ||
                                  _currentSort == SortType.lostChapterCustom)
                              ? null
                              : _changeSortType,
                          disabledHint: Text(
                            _getSortDisplayName(SortType.none),
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          items: SortType.values
                              .where(
                                (sort) =>
                                    sort != SortType.fallChapterCustom &&
                                    sort != SortType.lostChapterCustom,
                              )
                              .map((SortType sort) {
                                return DropdownMenuItem<SortType>(
                                  value: sort,
                                  child: Text(_getSortDisplayName(sort)),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showAdvancedSortDialog,
                      icon: const Icon(Icons.sort),
                      label: const Text('高级排序'),
                    ),
                  ),
                  // 失落章节排序信息显示
                  if (_currentSort == SortType.lostChapterCustom)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 18,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '失落章节排序已启用',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: _showLostChapterSortDialog,
                                tooltip: '编辑相性契合',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: _clearLostChapterSort,
                                tooltip: '清除',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '已设置相性契合: ${_affinityCoefficients.entries.where((e) => e.value != 1.0).length} 个搭档',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (_affinityCoefficients.isNotEmpty)
                            const SizedBox(height: 4),
                          if (_affinityCoefficients.entries
                              .where((e) => e.value != 1.0)
                              .isNotEmpty)
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: _affinityCoefficients.entries
                                  .where((e) => e.value != 1.0)
                                  .take(5)
                                  .map(
                                    (entry) => Chip(
                                      label: Text(
                                        '${entry.key}: ${entry.value.toStringAsFixed(1)}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 0,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                  .toList(),
                            ),
                          if (_affinityCoefficients.entries
                                  .where((e) => e.value != 1.0)
                                  .length >
                              5)
                            Text(
                              '... 还有 ${_affinityCoefficients.entries.where((e) => e.value != 1.0).length - 5} 个',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  // 陷落章节排序信息显示
                  if (_currentSort == SortType.fallChapterCustom)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.deepPurple.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.trending_down,
                                size: 18,
                                color: Colors.deepPurple[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '陷落章节排序已启用',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple[700],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: _showFallChapterSortDialog,
                                tooltip: '更改排序方式',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: _clearFallChapterSort,
                                tooltip: '清除',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          if (_fallChapterMethod != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '排序方式: ${_getFallChapterMethodName(_fallChapterMethod!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _partners.isEmpty
                ? Center(
                    child: _isFetching
                        ? const Text('正在获取搭档数据...')
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('暂无搭档数据'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _startFetching,
                                child: const Text('获取数据'),
                              ),
                            ],
                          ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _partners.length,
                    itemBuilder: (context, index) {
                      final partner = _partners[index];
                      return _buildPartnerCard(partner);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(PartnerData partner) {
    final isSetAsAvatar = widget.settings.selectedPartnerIconUrl == partner.iconUrl;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showSetAvatarDialog(partner),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon with retry mechanism
                    _buildPartnerIcon(partner),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partner.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: Text(
                                  'Lv.${partner.level}',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.purple),
                                ),
                                child: Text(
                                  partner.type,
                                  style: const TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (partner.skill != null &&
                              partner.skill!.isNotEmpty)
                            Text(
                              partner.skill!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStatsRow(partner),
              ],
            ),
          ),
          if (isSetAsAvatar)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_circle, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'PTT头像',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (partner.isSelected)
            Positioned(
              top: 0,
              right: isSetAsAvatar ? 100 : 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: const Text(
                  '已选中',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(PartnerData partner) {
    final isLostChapterSort = _currentSort == SortType.lostChapterCustom;
    final isFallChapterSort = _currentSort == SortType.fallChapterCustom;
    final lostScore = _lostChapterScores[partner.name];
    final fallScore = _fallChapterScores[partner.name];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Frag', partner.frag.toString()),
        _buildStatItem('Step', partner.step.toString()),
        _buildStatItem('Over', partner.overdrive.toString()),
        if (isLostChapterSort && lostScore != null)
          _buildStatItem(
            '失落章节',
            lostScore.toStringAsFixed(1),
            color: Colors.orange,
          ),
        if (isFallChapterSort && fallScore != null)
          _buildStatItem(
            '进度',
            fallScore.toStringAsFixed(2),
            color: Colors.deepPurple,
          ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color ?? Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildPartnerIcon(PartnerData partner) {
    if (partner.iconUrl.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: const Icon(Icons.person, size: 40, color: Colors.grey),
      );
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          partner.iconUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 30, color: Colors.grey[400]),
                  const SizedBox(height: 4),
                  Text(
                    '加载失败',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
