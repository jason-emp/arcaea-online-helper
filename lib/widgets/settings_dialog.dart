import 'package:flutter/material.dart';

/// 显示设置对话框
Future<void> showSettingsDialog({
  required BuildContext context,
  required VoidCallback onGenerateImage,
  required VoidCallback onDownloadLatest,
  required VoidCallback onCheckUpdate,
  required VoidCallback onUpdateData,
  required VoidCallback onClearAllData,
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
      onGenerateImage: onGenerateImage,
      onDownloadLatest: onDownloadLatest,
      onCheckUpdate: onCheckUpdate,
      onUpdateData: onUpdateData,
      onClearAllData: onClearAllData,
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

  const _SettingsDialog({
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
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      '危险操作',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _showClearDataConfirmDialog(context),
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text(
                        '清除所有数据',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '将清除所有成绩记录、B30/R10 数据、排序设置和登录信息',
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
              Navigator.of(context).pop(); // 关闭设置对话框
              onClearAllData(); // 执行清除操作
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
