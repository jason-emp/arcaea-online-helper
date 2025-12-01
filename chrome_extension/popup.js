// Arcaea Helper - Settings Popup Script

// 默认设置
const DEFAULT_SETTINGS = {
  showCharts: false,  // 默认隐藏PTT变化图表
  showConstant: true,
  showPTT: true,
  showTargetScore: true,
  showDownloadButtons: true  // 默认显示下载按钮
};

// 加载设置
async function loadSettings() {
  try {
    const result = await chrome.storage.sync.get(DEFAULT_SETTINGS);
    // 应用设置到UI
    document.getElementById('showCharts').checked = result.showCharts;
    document.getElementById('showConstant').checked = result.showConstant;
    document.getElementById('showPTT').checked = result.showPTT;
    document.getElementById('showTargetScore').checked = result.showTargetScore;
    document.getElementById('showDownloadButtons').checked = result.showDownloadButtons;
    
    console.log('[Arcaea Helper Settings] 设置已加载:', result);
  } catch (error) {
    console.error('[Arcaea Helper Settings] 加载设置失败:', error);
  }
}

// 保存设置
async function saveSettings() {
  try {
    const settings = {
      showCharts: document.getElementById('showCharts').checked,
      showConstant: document.getElementById('showConstant').checked,
      showPTT: document.getElementById('showPTT').checked,
      showTargetScore: document.getElementById('showTargetScore').checked,
      showDownloadButtons: document.getElementById('showDownloadButtons').checked
    };
    
    await chrome.storage.sync.set(settings);
    
    console.log('[Arcaea Helper Settings] 设置已保存:', settings);
    
    // 显示保存提示
    showStatusMessage('✓ 设置已保存');
    
    // 通知所有标签页更新设置
    const allTabs = await chrome.tabs.query({ url: 'https://arcaea.lowiro.com/*/*' });
    const arcaeaTabs = allTabs.filter(tab => 
      tab.url && tab.url.includes('/profile/potential')
    );
    
    arcaeaTabs.forEach(tab => {
      chrome.tabs.sendMessage(tab.id, {
        type: 'SETTINGS_UPDATED',
        settings: settings
      }).catch(() => {
        // 忽略错误（页面可能未加载脚本）
      });
    });
  } catch (error) {
    console.error('[Arcaea Helper Settings] 保存设置失败:', error);
    showStatusMessage('✗ 保存失败', 'error');
  }
}

// 显示状态消息
function showStatusMessage(message, type = 'success') {
  const statusElement = document.getElementById('statusMessage');
  const textElement = statusElement.querySelector('[data-snackbar-text]');
  const iconElement = statusElement.querySelector('[data-snackbar-icon]');

  textElement.textContent = message;
  statusElement.classList.remove('success', 'error');

  if (type === 'error') {
    statusElement.classList.add('error');
    if (iconElement) iconElement.textContent = 'error';
  } else {
    statusElement.classList.add('success');
    if (iconElement) iconElement.textContent = 'check_circle';
  }

  statusElement.classList.add('show');
  
  setTimeout(() => {
    statusElement.classList.remove('show');
  }, 2000);
}

// 检查更新
function checkForUpdates() {
  const releaseUrl = 'https://github.com/jason-emp/arcaea-online-helper/releases/latest';
  
  chrome.tabs.create({ url: releaseUrl }, (tab) => {
    if (chrome.runtime.lastError) {
      console.error('[Arcaea Helper Settings] 打开更新页面失败:', chrome.runtime.lastError);
      showStatusMessage('✗ 无法打开更新页面', 'error');
    } else {
      console.log('[Arcaea Helper Settings] 已打开更新页面');
      showStatusMessage('✓ 正在跳转到更新页面');
    }
  });
}

// 导出数据
async function exportData() {
  try {
    // 查找Arcaea页面 - 使用更宽松的匹配，然后手动过滤
    const tabs = await chrome.tabs.query({ 
      url: 'https://arcaea.lowiro.com/*/*' 
    });
    
    // 手动过滤出 profile/potential 页面
    const arcaeaTabs = tabs.filter(tab => 
      tab.url && tab.url.includes('/profile/potential')
    );
    
    if (arcaeaTabs.length === 0) {
      showStatusMessage('✗ 请先打开Arcaea查分页面', 'error');
      return;
    }
    
    const tab = arcaeaTabs[0];
    
    // 向content script发送消息请求数据
    chrome.tabs.sendMessage(tab.id, { type: 'EXPORT_DATA' }, (response) => {
      if (chrome.runtime.lastError) {
        console.error('[Arcaea Helper Settings] 导出失败:', chrome.runtime.lastError);
        showStatusMessage('✗ 导出失败，请刷新页面重试', 'error');
        return;
      }
      
      if (!response || !response.success || !response.data) {
        showStatusMessage('✗ 无法获取数据', 'error');
        return;
      }
      
      // 下载JSON文件
      const dataStr = JSON.stringify(response.data, null, 2);
      const blob = new Blob([dataStr], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
      const filename = `arcaea-b30r10-${timestamp}.json`;
      
      chrome.downloads.download({
        url: url,
        filename: filename,
        saveAs: true
      }, (downloadId) => {
        if (chrome.runtime.lastError) {
          console.error('[Arcaea Helper Settings] 下载失败:', chrome.runtime.lastError);
          showStatusMessage('✗ 下载失败', 'error');
        } else {
          console.log('[Arcaea Helper Settings] 数据已导出:', downloadId);
          showStatusMessage('✓ 数据已导出');
          URL.revokeObjectURL(url);
        }
      });
    });
  } catch (error) {
    console.error('[Arcaea Helper Settings] 导出数据错误:', error);
    showStatusMessage('✗ 导出失败', 'error');
  }
}

// 初始化
document.addEventListener('DOMContentLoaded', () => {
  // 加载设置
  loadSettings();
  
  // 监听设置变化
  const settingCheckboxes = [
    'showCharts',
    'showConstant',
    'showPTT',
    'showTargetScore',
    'showDownloadButtons'
  ];
  
  settingCheckboxes.forEach(id => {
    document.getElementById(id).addEventListener('change', saveSettings);
  });
  
  // 监听检查更新按钮
  document.getElementById('checkUpdateButton').addEventListener('click', checkForUpdates);
  
  // 监听导出数据按钮
  document.getElementById('exportDataButton').addEventListener('click', exportData);
  
  console.log('[Arcaea Helper Settings] 设置页面已初始化');
});
