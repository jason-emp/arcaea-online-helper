import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// 设置面板Widget
class SettingsPanel extends StatelessWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback onGenerateImage;
  final VoidCallback onDownloadLatest;
  final VoidCallback onCheckUpdate;
  final bool isCheckingUpdate;
  final bool isGeneratingImage;
  final bool canGenerateImage;
  final String? currentVersion;
  final String? latestVersion;
  final String? updateStatusMessage;

  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.onGenerateImage,
    required this.onDownloadLatest,
    required this.onCheckUpdate,
    this.isCheckingUpdate = false,
    this.isGeneratingImage = false,
    this.canGenerateImage = false,
    this.currentVersion,
    this.latestVersion,
    this.updateStatusMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
        ],
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
}
