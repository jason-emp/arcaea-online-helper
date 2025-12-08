import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/score_filter.dart';
import '../services/song_data_service.dart';

/// 成绩筛选对话框
class ScoreFilterDialog extends StatefulWidget {
  final ScoreFilter initialFilter;

  const ScoreFilterDialog({
    super.key,
    required this.initialFilter,
  });

  @override
  State<ScoreFilterDialog> createState() => _ScoreFilterDialogState();
}

class _ScoreFilterDialogState extends State<ScoreFilterDialog> {
  late Set<String> _selectedDifficulties;
  late Set<String> _selectedPacks;
  late TextEditingController _constantMaxController;
  late TextEditingController _constantMinController;
  late TextEditingController _pttMaxController;
  late TextEditingController _pttMinController;
  late TextEditingController _scoreMaxController;
  late TextEditingController _scoreMinController;
  late TextEditingController _targetMaxController;
  late TextEditingController _targetMinController;
  late bool _onlyWithTarget;

  final SongDataService _songDataService = SongDataService();
  List<String> _availablePacks = [];
  bool _packsLoaded = false;

  // 难度列表
  static const List<String> difficulties = ['PST', 'PRS', 'FTR', 'BYD', 'ETR'];

  // 定数预设值（9-12的整数和.5）
  static const List<double> constantPresets = [
    9.0, 9.5, 10.0, 10.5, 11.0, 11.5, 12.0
  ];

  // 成绩预设值
  static const Map<String, int> scorePresets = ScoreFilter.scorePresets;

  @override
  void initState() {
    super.initState();
    _selectedDifficulties = Set.from(widget.initialFilter.difficulties);
    _selectedPacks = Set.from(widget.initialFilter.packs);
    _constantMaxController = TextEditingController(
      text: widget.initialFilter.constantMax?.toStringAsFixed(1) ?? '',
    );
    _constantMinController = TextEditingController(
      text: widget.initialFilter.constantMin?.toStringAsFixed(1) ?? '',
    );
    _pttMaxController = TextEditingController(
      text: widget.initialFilter.pttMax?.toStringAsFixed(2) ?? '',
    );
    _pttMinController = TextEditingController(
      text: widget.initialFilter.pttMin?.toStringAsFixed(2) ?? '',
    );
    _scoreMaxController = TextEditingController(
      text: widget.initialFilter.scoreMax?.toString() ?? '',
    );
    _scoreMinController = TextEditingController(
      text: widget.initialFilter.scoreMin?.toString() ?? '',
    );
    _targetMaxController = TextEditingController(
      text: widget.initialFilter.targetMax?.toString() ?? '',
    );
    _targetMinController = TextEditingController(
      text: widget.initialFilter.targetMin?.toString() ?? '',
    );
    _onlyWithTarget = widget.initialFilter.onlyWithTarget;
    _loadPacks();
  }

  Future<void> _loadPacks() async {
    await _songDataService.ensureLoaded();
    setState(() {
      _availablePacks = _songDataService.getAllPacks();
      _packsLoaded = true;
    });
  }

  @override
  void dispose() {
    _constantMaxController.dispose();
    _constantMinController.dispose();
    _pttMaxController.dispose();
    _pttMinController.dispose();
    _scoreMaxController.dispose();
    _scoreMinController.dispose();
    _targetMaxController.dispose();
    _targetMinController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final filter = ScoreFilter(
      difficulties: _selectedDifficulties,
      packs: _selectedPacks,
      constantMax: _parseDouble(_constantMaxController.text),
      constantMin: _parseDouble(_constantMinController.text),
      pttMax: _parseDouble(_pttMaxController.text),
      pttMin: _parseDouble(_pttMinController.text),
      scoreMax: _parseInt(_scoreMaxController.text),
      scoreMin: _parseInt(_scoreMinController.text),
      targetMax: _parseInt(_targetMaxController.text),
      targetMin: _parseInt(_targetMinController.text),
      onlyWithTarget: _onlyWithTarget,
    );
    Navigator.of(context).pop(filter);
  }

  void _clearFilter() {
    setState(() {
      _selectedDifficulties.clear();
      _selectedPacks.clear();
      _constantMaxController.clear();
      _constantMinController.clear();
      _pttMaxController.clear();
      _pttMinController.clear();
      _scoreMaxController.clear();
      _scoreMinController.clear();
      _targetMaxController.clear();
      _targetMinController.clear();
      _onlyWithTarget = false;
    });
  }

  double? _parseDouble(String text) {
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  int? _parseInt(String text) {
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '筛选条件',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearFilter,
                    child: const Text('清除'),
                  ),
                ],
              ),
            ),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 难度筛选
                    _buildSectionTitle('难度'),
                    _buildDifficultySelector(),
                    const SizedBox(height: 16),

                    // 曲包筛选
                    _buildSectionTitle('曲包'),
                    _buildPackSelector(),
                    const SizedBox(height: 16),

                    // 谱面定数
                    _buildSectionTitle('谱面定数'),
                    _buildRangeInput(
                      minController: _constantMinController,
                      maxController: _constantMaxController,
                      presets: constantPresets.map((v) => v.toString()).toList(),
                      inputType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
                      ],
                      formatValue: (v) => double.tryParse(v)?.toStringAsFixed(1) ?? v,
                    ),
                    const SizedBox(height: 16),

                    // 单曲PTT
                    _buildSectionTitle('单曲PTT'),
                    _buildRangeInput(
                      minController: _pttMinController,
                      maxController: _pttMaxController,
                      presets: null,
                      inputType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 成绩
                    _buildSectionTitle('成绩'),
                    _buildRangeInput(
                      minController: _scoreMinController,
                      maxController: _scoreMaxController,
                      presets: scorePresets.keys.toList(),
                      inputType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      presetToValue: (preset) => scorePresets[preset]?.toString() ?? '',
                    ),
                    const SizedBox(height: 16),

                    // 目标
                    _buildSectionTitle('目标'),
                    CheckboxListTile(
                      title: const Text('仅显示有目标的曲目'),
                      value: _onlyWithTarget,
                      onChanged: (value) {
                        setState(() {
                          _onlyWithTarget = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    _buildRangeInput(
                      minController: _targetMinController,
                      maxController: _targetMaxController,
                      presets: scorePresets.keys.toList(),
                      inputType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      presetToValue: (preset) => scorePresets[preset]?.toString() ?? '',
                    ),
                  ],
                ),
              ),
            ),

            // 按钮栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _applyFilter,
                    child: const Text('应用'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: difficulties.map((difficulty) {
        final isSelected = _selectedDifficulties.contains(difficulty);
        return FilterChip(
          label: Text(difficulty),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedDifficulties.add(difficulty);
              } else {
                _selectedDifficulties.remove(difficulty);
              }
            });
          },
          selectedColor: _getDifficultyColor(difficulty).withOpacity(0.3),
          checkmarkColor: _getDifficultyColor(difficulty),
        );
      }).toList(),
    );
  }

  Widget _buildPackSelector() {
    if (!_packsLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_availablePacks.isEmpty) {
      return const Text(
        '暂无可用曲包',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 快捷操作按钮
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedPacks.addAll(_availablePacks);
                });
              },
              icon: const Icon(Icons.select_all, size: 16),
              label: const Text('全选', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedPacks.clear();
                });
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('清除', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 曲包选择区域 - 使用容器限制高度
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availablePacks.length,
            itemBuilder: (context, index) {
              final pack = _availablePacks[index];
              final isSelected = _selectedPacks.contains(pack);
              return CheckboxListTile(
                dense: true,
                title: Text(
                  pack,
                  style: const TextStyle(fontSize: 13),
                ),
                value: isSelected,
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedPacks.add(pack);
                    } else {
                      _selectedPacks.remove(pack);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRangeInput({
    required TextEditingController minController,
    required TextEditingController maxController,
    required List<String>? presets,
    required TextInputType inputType,
    required List<TextInputFormatter> inputFormatters,
    String Function(String)? formatValue,
    String Function(String)? presetToValue,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: minController,
                keyboardType: inputType,
                inputFormatters: inputFormatters,
                decoration: const InputDecoration(
                  labelText: '下限',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—'),
            ),
            Expanded(
              child: TextField(
                controller: maxController,
                keyboardType: inputType,
                inputFormatters: inputFormatters,
                decoration: const InputDecoration(
                  labelText: '上限',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        if (presets != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: presets.map((preset) {
              return ActionChip(
                label: Text(preset),
                onPressed: () {
                  setState(() {
                    final value = presetToValue?.call(preset) ?? preset;
                    final formatted = formatValue?.call(value) ?? value;
                    // 如果下限为空，设置为下限；否则设置为上限
                    if (minController.text.isEmpty) {
                      minController.text = formatted;
                    } else {
                      maxController.text = formatted;
                    }
                  });
                },
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'PST':
        return const Color(0xFF4A9C6D);
      case 'PRS':
        return const Color(0xFFE8B600);
      case 'FTR':
        return const Color(0xFF8B5A9E);
      case 'BYD':
        return const Color(0xFFDC143C);
      case 'ETR':
        return const Color(0xFF000000);
      default:
        return Colors.grey;
    }
  }
}
