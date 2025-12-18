import 'package:flutter/material.dart';

/// 难度选择对话框
class DifficultySelectorDialog extends StatefulWidget {
  const DifficultySelectorDialog({super.key});

  @override
  State<DifficultySelectorDialog> createState() =>
      _DifficultySelectorDialogState();
}

class _DifficultySelectorDialogState extends State<DifficultySelectorDialog> {
  final Map<String, bool> _selectedDifficulties = {
    'PST': true,
    'PRS': true,
    'FTR': true,
    'ETR': true,
    'BYD': true,
  };

  final Map<String, String> _difficultyNames = {
    'PST': 'Past',
    'PRS': 'Present',
    'FTR': 'Future',
    'ETR': 'Eternal',
    'BYD': 'Beyond',
  };

  final Map<String, Color> _difficultyColors = {
    'PST': const Color(0xFF6DD5ED),
    'PRS': const Color(0xFF9EDE73),
    'FTR': const Color(0xFFB370CF),
    'ETR': const Color(0xFFE74C3C),
    'BYD': const Color(0xFFE74C3C),
  };

  bool get _hasSelection =>
      _selectedDifficulties.values.any((selected) => selected);

  void _toggleAll(bool value) {
    setState(() {
      _selectedDifficulties.updateAll((key, _) => value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择要更新的难度'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 全选/全不选按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _toggleAll(true),
                  icon: const Icon(Icons.check_box, size: 20),
                  label: const Text('全选'),
                ),
                TextButton.icon(
                  onPressed: () => _toggleAll(false),
                  icon: const Icon(Icons.check_box_outline_blank, size: 20),
                  label: const Text('全不选'),
                ),
              ],
            ),
            const Divider(),
            // 难度选择列表
            ..._selectedDifficulties.keys.map((difficulty) {
              return CheckboxListTile(
                title: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _difficultyColors[difficulty],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_difficultyNames[difficulty] ?? difficulty),
                    const SizedBox(width: 8),
                    Text(
                      '($difficulty)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                value: _selectedDifficulties[difficulty],
                onChanged: (value) {
                  setState(() {
                    _selectedDifficulties[difficulty] = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _hasSelection
              ? () {
                  final selectedDifficulties = _selectedDifficulties.entries
                      .where((entry) => entry.value)
                      .map((entry) => entry.key)
                      .toList();
                  Navigator.of(context).pop(selectedDifficulties);
                }
              : null,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
