import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// 显示设置对话框
Future<void> showSettingsDialog({
  required BuildContext context,
  required AppSettings settings,
  required ValueChanged<AppSettings> onSettingsChanged,
  required VoidCallback onGenerateImage,
  required VoidCallback onDownloadLatest,
  required VoidCallback onCheckUpdate,
  required VoidCallback onUpdateData,
  required bool isCheckingUpdate,
  required bool isGeneratingImage,
  required bool isUpdatingData,
  required bool canGenerateImage,
  String? currentVersion,
  String? latestVersion,
  String? updateStatusMessage,
  String? dataUpdateMessage,
  DateTime? lastDataUpdateTime,
}) async {
  return showDialog<void>(
    context: context,
    builder: (context) => _SettingsDialog(
      settings: settings,
      onSettingsChanged: onSettingsChanged,
      onGenerateImage: onGenerateImage,
      onDownloadLatest: onDownloadLatest,
      onCheckUpdate: onCheckUpdate,
      onUpdateData: onUpdateData,
      isCheckingUpdate: isCheckingUpdate,
      isGeneratingImage: isGeneratingImage,
      isUpdatingData: isUpdatingData,
      canGenerateImage: canGenerateImage,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      updateStatusMessage: updateStatusMessage,
      dataUpdateMessage: dataUpdateMessage,
      lastDataUpdateTime: lastDataUpdateTime,
    ),
  );
}

/// 设置对话框Widget
class _SettingsDialog extends StatelessWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback onGenerateImage;
  final VoidCallback onDownloadLatest;
  final VoidCallback onCheckUpdate;
  final VoidCallback onUpdateData;
  final bool isCheckingUpdate;
  final bool isGeneratingImage;
  final bool isUpdatingData;
  final bool canGenerateImage;
  final String? currentVersion;
  final String? latestVersion;
  final String? updateStatusMessage;
  final String? dataUpdateMessage;
  final DateTime? lastDataUpdateTime;

  const _SettingsDialog({
    required this.settings,
    required this.onSettingsChanged,
    required this.onGenerateImage,
    required this.onDownloadLatest,
    required this.onCheckUpdate,
    required this.onUpdateData,
    this.isCheckingUpdate = false,
    this.isGeneratingImage = false,
    this.isUpdatingData = false,
    this.canGenerateImage = false,
    this.currentVersion,
    this.latestVersion,
    this.updateStatusMessage,
    this.dataUpdateMessage,
    this.lastDataUpdateTime,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
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
                    Icons.settings,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Arcaea Helper 设置',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
            // 可滚动内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '显示设置',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildSettingSwitch(
                      '显示图表',
                      'Best 30 / Recent 10 的 PTT 变化图表',
                      settings.showCharts,
                      (value) => onSettingsChanged(settings.copyWith(showCharts: value)),
                    ),
                    _buildSettingSwitch(
                      '显示定数',
                      '在曲目名称旁显示谱面定数',
                      settings.showConstant,
                      (value) => onSettingsChanged(settings.copyWith(showConstant: value)),
                    ),
                    _buildSettingSwitch(
                      '显示单曲PTT',
                      '在曲目旁显示该曲目的PTT值',
                      settings.showPTT,
                      (value) => onSettingsChanged(settings.copyWith(showPTT: value)),
                    ),
                    _buildSettingSwitch(
                      '显示目标分数',
                      '显示使显示PTT +0.01 所需的目标分数',
                      settings.showTargetScore,
                      (value) => onSettingsChanged(settings.copyWith(showTargetScore: value)),
                    ),
                    _buildSettingSwitch(
                      '显示下载按钮',
                      '显示截图下载和背景选择按钮',
                      settings.showDownloadButtons,
                      (value) => onSettingsChanged(settings.copyWith(showDownloadButtons: value)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: canGenerateImage && !isGeneratingImage ? onGenerateImage : null,
                            icon: const Icon(Icons.image),
                            label: const Text('生成B30/R10图片'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '自动获取页面数据并生成精美图片',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onDownloadLatest,
                      icon: const Icon(Icons.download),
                      label: const Text('下载最新版本'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '跳转至GitHub发布页下载最新版本',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: isCheckingUpdate ? null : onCheckUpdate,
                      icon: isCheckingUpdate
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.system_update_alt),
                      label: Text(isCheckingUpdate ? '检查中...' : '检查更新'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _buildVersionInfoText(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      updateStatusMessage ?? '点击"检查更新"以获取最新版本信息',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '数据管理',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: isUpdatingData ? null : onUpdateData,
                      icon: isUpdatingData
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download),
                      label: Text(isUpdatingData ? '更新中...' : '更新曲目数据'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _buildDataUpdateInfoText(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dataUpdateMessage ?? '从 GitHub 下载最新的曲目列表和定数数据',
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

  Widget _buildSettingSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  String _buildVersionInfoText() {
    final parts = <String>[];
    if (currentVersion != null) {
      parts.add('当前版本 $currentVersion');
    }
    if (latestVersion != null) {
      parts.add('最新版本 $latestVersion');
    }
    return parts.isEmpty ? '当前版本信息暂不可用' : parts.join(' · ');
  }

  String _buildDataUpdateInfoText() {
    if (lastDataUpdateTime == null) {
      return '尚未更新过数据';
    }
    final now = DateTime.now();
    final diff = now.difference(lastDataUpdateTime!);
    
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
}
