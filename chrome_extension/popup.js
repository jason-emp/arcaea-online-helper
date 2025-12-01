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
    chrome.tabs.query({ url: 'https://arcaea.lowiro.com/*/profile/potential*' }, (tabs) => {
      tabs.forEach(tab => {
        chrome.tabs.sendMessage(tab.id, {
          type: 'SETTINGS_UPDATED',
          settings: settings
        }).catch(() => {
          // 忽略错误（页面可能未加载脚本）
        });
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
  
  console.log('[Arcaea Helper Settings] 设置页面已初始化');
});
