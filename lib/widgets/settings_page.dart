import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  final VoidCallback onGenerateImage;
  final VoidCallback onDownloadLatest;
  final VoidCallback onCheckUpdate;
  final VoidCallback onUpdateData;
  final VoidCallback onClearAllData;
  final bool isCheckingUpdate;
  final bool isGeneratingImage;
  final bool isUpdatingData;
  final bool canGenerateImage;
  final String? currentVersion;
  final String? latestVersion;
  final String? updateStatusMessage;
  final String? dataUpdateMessage;
  final DateTime? lastDataUpdateTime;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  const SettingsPage({
    super.key,
    required this.onGenerateImage,
    required this.onDownloadLatest,
    required this.onCheckUpdate,
    required this.onUpdateData,
    required this.onClearAllData,
    this.isCheckingUpdate = false,
    this.isGeneratingImage = false,
    this.isUpdatingData = false,
    this.canGenerateImage = false,
    this.currentVersion,
    this.latestVersion,
    this.updateStatusMessage,
    this.dataUpdateMessage,
    this.lastDataUpdateTime,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings != oldWidget.settings) {
      setState(() {
        _settings = widget.settings;
      });
    }
  }

  Widget _buildExtraBestSongsControl() {
    const options = [0, 5, 10, 15, 20];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '显示更多 Best 曲目',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _settings.extraBestSongsCount,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: options
              .map(
                (value) => DropdownMenuItem<int>(
                  value: value,
                  child: Text(value == 0 ? '关闭' : '+$value'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            _updateSettings(
              _settings.copyWith(extraBestSongsCount: value),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          '需要先在成绩列表页拉取成绩，追加曲目将显示在 B30 下方',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  void _updateSettings(AppSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    widget.onSettingsChanged(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 版本与更新
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 8),
                        Text(
                          '版本与更新',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.onDownloadLatest,
                        icon: const Icon(Icons.download),
                        label: const Text('下载最新版本'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '跳转至GitHub发布页下载最新版本',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.isCheckingUpdate
                            ? null
                            : widget.onCheckUpdate,
                        icon: widget.isCheckingUpdate
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.system_update_alt),
                        label:
                            Text(widget.isCheckingUpdate ? '检查中...' : '检查更新'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _buildVersionInfoText(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.updateStatusMessage ?? '点击"检查更新"以获取最新版本信息',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 显示设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.visibility_outlined),
                        SizedBox(width: 8),
                        Text(
                          '显示设置',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildExtraBestSongsControl(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 数据管理
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storage_outlined),
                        SizedBox(width: 8),
                        Text(
                          '数据管理',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            widget.isUpdatingData ? null : widget.onUpdateData,
                        icon: widget.isUpdatingData
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_download),
                        label: Text(
                            widget.isUpdatingData ? '更新中...' : '更新曲目数据'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _buildDataUpdateInfoText(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.dataUpdateMessage ??
                          '从 GitHub 下载最新的曲目列表和定数数据',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 危险操作
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_outlined, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          '危险操作',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showClearDataConfirmDialog(context),
                        icon:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text(
                          '清除所有数据',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '将清除所有成绩记录、B30/R10 数据、搭档数据、排序设置和登录信息',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildVersionInfoText() {
    final parts = <String>[];
    if (widget.currentVersion != null) {
      parts.add('当前版本 ${widget.currentVersion}');
    }
    if (widget.latestVersion != null) {
      parts.add('最新版本 ${widget.latestVersion}');
    }
    return parts.isEmpty ? '当前版本信息暂不可用' : parts.join(' · ');
  }

  String _buildDataUpdateInfoText() {
    if (widget.lastDataUpdateTime == null) {
      return '尚未更新过数据';
    }
    final now = DateTime.now();
    final diff = now.difference(widget.lastDataUpdateTime!);

    if (diff.inDays > 0) {
      return '上次更新: ${diff.inDays} 天前';
    } else if (diff.inHours > 0) {
      return '上次更新: ${diff.inHours} 小时前';
    } else if (diff.inMinutes > 0) {
      return '上次更新: ${diff.inMinutes} 分钟前';
    } else {
      return '上次更新: 刚刚';
    }
  }

  /// 显示清除数据确认对话框
  void _showClearDataConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.red, size: 48),
        title: const Text('确认清除所有数据'),
        content: const Text(
          '此操作将永久删除：\n\n'
          '• 所有成绩记录\n'
          '• B30/R10 数据\n'
          '• 搭档数据\n'
          '• 排序设置\n'
          '• 登录信息（Cookies）\n\n'
          '清除后需要重新登录，此操作无法撤销，确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // 关闭确认对话框
              widget.onClearAllData(); // 执行清除操作
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }
}
