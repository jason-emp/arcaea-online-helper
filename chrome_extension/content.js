// Arcaea Online Chart Constant Helper - Content Script
// 使用 shared_core 的模块化版本

(async function() {
  'use strict';

  console.log('[Arcaea Helper] 🚀 扩展已加载');
  console.log('[Arcaea Helper] 当前页面:', window.location.href);

  // 禁用网页的选中和复制限制
  (function enableTextSelection() {
    // 移除所有阻止选择和复制的事件监听器
    const events = ['selectstart', 'copy', 'cut', 'contextmenu', 'mousedown', 'mouseup'];
    events.forEach(event => {
      document.addEventListener(event, function(e) {
        e.stopPropagation();
      }, true);
    });

    // 注入 CSS 以启用文本选择
    const style = document.createElement('style');
    style.id = 'arcaea-enable-selection';
    style.textContent = `
      * {
        -webkit-user-select: text !important;
        -moz-user-select: text !important;
        -ms-user-select: text !important;
        user-select: text !important;
      }
    `;
    document.head.appendChild(style);

    console.log('[Arcaea Helper] ✅ 已启用文本选择和复制功能');
  })();

  // 默认设置
  const DEFAULT_SETTINGS = {
    showCharts: false,
    showConstant: true,
    showPTT: true,
    showTargetScore: true,
    showDownloadButtons: true
  };

  let currentSettings = { ...DEFAULT_SETTINGS };
  let dataLoader = null;
  let processedElements = new WeakSet();
  let debugFirstCard = true;
  let currentUrl = window.location.href;
  let domObserver = null;

  // 加载设置
  async function loadSettings() {
    try {
      const result = await chrome.storage.sync.get(DEFAULT_SETTINGS);
      currentSettings = result;
      console.log('[Arcaea Helper] ✅ 设置已加载:', currentSettings);
      applySettings();
    } catch (error) {
      console.error('[Arcaea Helper] 加载设置失败:', error);
      currentSettings = { ...DEFAULT_SETTINGS };
    }
  }

  // 应用设置
  function applySettings() {
    console.log('[Arcaea Helper] 应用设置:', currentSettings);
    
    if (currentSettings.showCharts) {
      showCharts();
    } else {
      hideCharts();
    }
    
    if (currentSettings.showDownloadButtons) {
      showDownloadButtons();
    } else {
      hideDownloadButtons();
    }
  }

  function hideCharts() {
    let styleElement = document.getElementById('arcaea-helper-chart-style');
    if (!styleElement) {
      styleElement = document.createElement('style');
      styleElement.id = 'arcaea-helper-chart-style';
      document.head.appendChild(styleElement);
    }
    
    styleElement.textContent = `
      .diagram-section,
      [data-v-337fbd7d].diagram-section,
      div[data-v-337fbd7d].diagram-section,
      .charts-wrap,
      [class*="charts-wrap"],
      .chart-container,
      [class*="chart-container"] {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        height: 0 !important;
        overflow: hidden !important;
      }
    `;
  }

  function showCharts() {
    const styleElement = document.getElementById('arcaea-helper-chart-style');
    if (styleElement) {
      styleElement.remove();
    }
  }

  function hideDownloadButtons() {
    let styleElement = document.getElementById('arcaea-helper-download-style');
    if (!styleElement) {
      styleElement = document.createElement('style');
      styleElement.id = 'arcaea-helper-download-style';
      document.head.appendChild(styleElement);
    }
    
    styleElement.textContent = `
      .download-container,
      [data-v-337fbd7d].download-container,
      div[data-v-337fbd7d].download-container {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        height: 0 !important;
        overflow: hidden !important;
      }
    `;
  }

  function showDownloadButtons() {
    const styleElement = document.getElementById('arcaea-helper-download-style');
    if (styleElement) {
      styleElement.remove();
    }
  }

  // 监听设置变化
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'SETTINGS_UPDATED') {
      console.log('[Arcaea Helper] 收到设置更新消息:', message.settings);
      currentSettings = message.settings;
      applySettings();
      
      setTimeout(() => {
        processedElements = new WeakSet();
        processAllCards();
      }, 100);
    } else if (message.type === 'EXPORT_DATA') {
      console.log('[Arcaea Helper] 收到导出数据请求');
      const exportData = collectExportData();
      sendResponse({ success: true, data: exportData });
      return true; // 保持消息通道开启以支持异步响应
    }
  });

  // 初始化数据加载器
  dataLoader = new window.ArcaeaDataLoader();
  
  // 加载数据
  const chartConstantUrl = chrome.runtime.getURL('data/ChartConstant.json');
  const songListUrl = chrome.runtime.getURL('data/Songlist.json');
  
  console.log('[Arcaea Helper] 正在加载数据...');
  const dataLoaded = await dataLoader.init(chartConstantUrl, songListUrl);
  
  if (!dataLoaded) {
    console.error('[Arcaea Helper] ❌ 数据加载失败');
    return;
  }

  await loadSettings();

  // 难度映射
  const difficultyTextMap = {
    'PST': 0, 'PAST': 0,
    'PRS': 1, 'PRESENT': 1,
    'FTR': 2, 'FUTURE': 2,
    'BYD': 3, 'BEYOND': 3,
    'ETR': 4, 'ETERNAL': 4
  };

  function getDifficultyFromElement(cardElement) {
    try {
      const difficultyLabels = cardElement.querySelectorAll('span.label, .label');
      
      for (const label of difficultyLabels) {
        const text = label.textContent.trim().toUpperCase();
        if (difficultyTextMap.hasOwnProperty(text)) {
          return difficultyTextMap[text];
        }
      }
      
      const allSpans = cardElement.querySelectorAll('span');
      for (const span of allSpans) {
        const text = span.textContent.trim().toUpperCase();
        if (difficultyTextMap.hasOwnProperty(text)) {
          return difficultyTextMap[text];
        }
      }
    } catch (error) {
      console.error('[Arcaea Helper] 获取难度失败:', error);
    }
    return null;
  }

  function getSongTitleAndScoreFromCard(cardElement) {
    try {
      let title = null;
      let score = null;

      const noOverflowSpans = cardElement.querySelectorAll('span.no-overflow');
      
      if (noOverflowSpans.length > 0) {
        title = noOverflowSpans[0].textContent.trim();
        if (title && title !== 'Title') {
          title = title.replace(/\s*\([\d.]+\)\s*$/, '').trim();
        } else {
          title = null;
        }
      }
      
      const exMainElements = cardElement.querySelectorAll('.ex-main, [class*="ex-main"]');
      for (const exMain of exMainElements) {
        const text = exMain.textContent.trim();
        const scoreMatch = text.match(/([\d,]+)/);
        if (scoreMatch) {
          const scoreStr = scoreMatch[1].replace(/,/g, '');
          const scoreNum = parseInt(scoreStr, 10);
          if (!isNaN(scoreNum) && scoreNum >= 0 && scoreNum <= 10000000) {
            score = scoreNum;
            break;
          }
        }
      }
      
      return { title, score };
    } catch (error) {
      console.error('[Arcaea Helper] 获取歌曲信息失败:', error);
    }
    return { title: null, score: null };
  }

  function addChartConstantAndPTT(titleElement, constant, score = null, cardElement = null, totalPTT = null) {
    if (!titleElement) return;
    
    if (titleElement.parentElement?.querySelector('.arcaea-chart-info')) {
      return;
    }
    
    if (processedElements.has(titleElement)) return;

    try {
      const container = document.createElement('span');
      container.className = 'arcaea-chart-info';
      container.style.marginLeft = '4px';
      container.style.whiteSpace = 'nowrap';
      container.style.display = 'inline-block';

      if (currentSettings.showConstant) {
        const constantSpan = document.createElement('span');
        constantSpan.className = 'arcaea-chart-constant';
        constantSpan.textContent = `(${window.ArcaeaCalculator.formatConstant(constant)})`;
        constantSpan.style.color = '#9ca3af';
        constantSpan.style.fontSize = '0.9em';
        
        container.appendChild(constantSpan);
      }

      if (currentSettings.showPTT && score !== null && score !== undefined) {
        const playPTT = window.ArcaeaCalculator.calculatePlayPTT(score, constant);
        if (playPTT !== null) {
          const pttSpan = document.createElement('span');
          pttSpan.className = 'arcaea-play-ptt';
          pttSpan.textContent = ` ${window.ArcaeaCalculator.formatPTT(playPTT)}`;
          pttSpan.style.color = '#667eea';
          pttSpan.style.fontSize = '0.9em';
          pttSpan.style.fontWeight = '700';
          pttSpan.style.marginLeft = '2px';
          
          container.appendChild(pttSpan);
        }
      }

      if (container.children.length > 0) {
        const parentElement = titleElement.parentElement;
        if (parentElement) {
          if (titleElement.nextSibling) {
            parentElement.insertBefore(container, titleElement.nextSibling);
          } else {
            parentElement.appendChild(container);
          }
        } else {
          titleElement.appendChild(container);
        }
      }
      
      processedElements.add(titleElement);
    } catch (error) {
      console.error('[Arcaea Helper] 添加定数显示失败:', error);
    }
  }

  function addTargetScore(cardElement, constant, currentScore, totalPTT = null) {
    try {
      if (cardElement.querySelector('.arcaea-target-score')) {
        return;
      }
      
      const scoreElements = cardElement.querySelectorAll('.ex-main, [class*="ex-main"]');
      if (scoreElements.length === 0) return;
      
      const scoreElement = scoreElements[0];
      const targetScore = window.ArcaeaCalculator.calculateTargetScore(constant, currentScore, totalPTT);
      
      const targetDiv = document.createElement('div');
      targetDiv.className = 'arcaea-target-score';
      targetDiv.style.fontSize = '0.85em';
      targetDiv.style.fontWeight = '600';
      targetDiv.style.marginTop = '2px';
      targetDiv.style.marginBottom = '0';
      targetDiv.style.textAlign = 'left';
      targetDiv.style.display = 'block';
      targetDiv.style.width = '100%';
      targetDiv.style.flexBasis = '100%';
      targetDiv.style.order = '999';
      
      if (targetScore !== null) {
        targetDiv.textContent = `>> ${window.ArcaeaCalculator.formatScore(targetScore)}`;
        targetDiv.style.color = '#10b981';
      } else {
        targetDiv.textContent = `无法推分`;
        targetDiv.style.color = '#ef4444';
      }
      
      const experienceContainer = scoreElement.closest('.experince, [class*="experince"]');
      if (experienceContainer) {
        experienceContainer.appendChild(targetDiv);
      } else {
        const parentElement = scoreElement.parentElement;
        if (parentElement) {
          parentElement.appendChild(targetDiv);
        }
      }
    } catch (error) {
      console.error('[Arcaea Helper] 添加目标分数失败:', error);
    }
  }

  function addCardIndex(cardElement, index, isRecent = false) {
    if (cardElement.querySelector('.arcaea-card-index')) {
      return;
    }
    
    if (cardElement.classList.contains('arcaea-indexed')) {
      return;
    }
    cardElement.classList.add('arcaea-indexed');

    try {
      const indexSpan = document.createElement('span');
      indexSpan.className = 'arcaea-card-index';
      indexSpan.textContent = isRecent ? `R${index}` : `#${index}`;
      
      if (isRecent) {
        indexSpan.setAttribute('data-recent', 'true');
      }
      
      cardElement.style.position = 'relative';
      cardElement.insertBefore(indexSpan, cardElement.firstChild);
    } catch (error) {
      console.error('[Arcaea Helper] 添加序号失败:', error);
    }
  }

  function processCard(cardElement, index = null, isRecent = false, totalPTT = null) {
    if (cardElement.classList.contains('arcaea-processed')) {
      const pttElement = cardElement.querySelector('.arcaea-play-ptt');
      if (pttElement) {
        const pttText = pttElement.textContent.trim();
        const pttValue = parseFloat(pttText);
        return isNaN(pttValue) ? null : pttValue;
      }
      return null;
    }
    
    if (processedElements.has(cardElement)) return null;

    try {
      const { title: songTitle, score } = getSongTitleAndScoreFromCard(cardElement);
      if (!songTitle) return null;

      const difficulty = getDifficultyFromElement(cardElement);
      if (difficulty === null) return null;

      const constant = dataLoader.getChartConstant(songTitle, difficulty, false);
      if (constant === null) return null;

      const titleElement = Array.from(cardElement.querySelectorAll('span, .title, [class*="title"]'))
        .find(el => el.textContent?.trim() === songTitle);
      
      let playPTT = null;
      if (titleElement) {
        addChartConstantAndPTT(titleElement, constant, score, cardElement, totalPTT);
        
        if (score !== null && score !== undefined) {
          playPTT = window.ArcaeaCalculator.calculatePlayPTT(score, constant);
        }
      }

      if (index !== null) {
        addCardIndex(cardElement, index, isRecent);
      }

      processedElements.add(cardElement);
      cardElement.classList.add('arcaea-processed');
      return playPTT;
    } catch (error) {
      console.error('[Arcaea Helper] 处理卡片失败:', error);
      return null;
    }
  }

  // 在 PTT 增长卡片的表格下方添加 B30/R10 信息
  function addB30R10InfoToFirstCard(best30Avg, recent10Avg) {
    try {
      const pttIncreaseCard = document.querySelector('.arcaea-ptt-increase-card');
      if (!pttIncreaseCard) return;
      
      // 移除已存在的信息
      const existing = pttIncreaseCard.querySelector('.arcaea-b30r10-info');
      if (existing) existing.remove();
      
      const infoDiv = document.createElement('div');
      infoDiv.className = 'arcaea-b30r10-info';
      infoDiv.innerHTML = `
        <div style="display: flex; justify-content: space-around; padding: 8px 12px; margin-top: 12px; background: linear-gradient(135deg, rgba(102, 126, 234, 0.1) 0%, rgba(234, 88, 12, 0.1) 100%); border-radius: 8px; border: 1px solid rgba(255, 255, 255, 0.3);">
          <span style="font-size: 13px; font-weight: 600; color: #333;">B30: ${best30Avg.toFixed(4)}</span>
          <span style="font-size: 13px; font-weight: 600; color: #333;">R10: ${recent10Avg.toFixed(4)}</span>
        </div>
      `;
      
      // 找到 PTT 增长卡片内部的内容容器
      const cardInner = pttIncreaseCard.querySelector('[data-v-b3942f14].card');
      if (cardInner) {
        cardInner.appendChild(infoDiv);
      }
    } catch (error) {
      console.error('[Arcaea Helper] 添加B30/R10信息失败:', error);
    }
  }

  function displayTotalPTT(totalPTT, best30PTTs, recent10PTTs) {
    try {
      if (document.querySelector('.arcaea-total-ptt')) {
        return;
      }
      
      const usernameElements = document.querySelectorAll('.username, [class*="username"]');
      if (usernameElements.length === 0) return;

      const usernameElement = usernameElements[0];
      
      // 昵称框只显示精确的PTT值
      const pttSpan = document.createElement('span');
      pttSpan.className = 'arcaea-total-ptt';
      pttSpan.textContent = ` (${totalPTT.toFixed(4)})`;
      pttSpan.style.color = '#667eea';
      pttSpan.style.fontSize = '0.9em';
      pttSpan.style.fontWeight = '700';
      pttSpan.style.marginLeft = '8px';
      pttSpan.style.whiteSpace = 'nowrap';

      const parentElement = usernameElement.parentElement;
      if (parentElement) {
        if (usernameElement.nextSibling) {
          parentElement.insertBefore(pttSpan, usernameElement.nextSibling);
        } else {
          parentElement.appendChild(pttSpan);
        }
      } else {
        usernameElement.appendChild(pttSpan);
      }
    } catch (error) {
      console.error('[Arcaea Helper] 显示总PTT失败:', error);
    }
  }

  function createPTTIncreaseCard(currentPTT, best30PTTs, recent10PTTs) {
    const requiredConstants = window.ArcaeaCalculator.calculateRequiredConstants(
      currentPTT, best30PTTs, recent10PTTs
    );
    
    const displayedPTT = Math.floor(currentPTT * 100) / 100;
    const targetPTT = displayedPTT + 0.01;

    const cardContainer = document.createElement('div');
    cardContainer.className = 'arcaea-ptt-increase-card';
    cardContainer.setAttribute('data-v-337fbd7d', '');
    cardContainer.classList.add('card');

    const cardInner = document.createElement('div');
    cardInner.setAttribute('data-v-b3942f14', '');
    cardInner.classList.add('card');
    cardInner.style.cssText = `
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      padding: 16px;
      display: flex;
      flex-direction: column;
      height: 100%;
      box-sizing: border-box;
    `;

    const title = document.createElement('div');
    title.style.cssText = `
      font-weight: 700;
      font-size: 14px;
      margin-bottom: 4px;
      text-align: center;
      color: #333;
    `;
    title.textContent = `使显示 PTT +0.01 所需最低谱面定数`;

    const subtitle = document.createElement('div');
    subtitle.style.cssText = `
      font-size: 11px;
      margin-bottom: 12px;
      text-align: center;
      color: #555;
    `;
    subtitle.textContent = `当前显示: ${displayedPTT.toFixed(2)} → 目标: ${targetPTT.toFixed(2)}`;
    
    const table = document.createElement('table');
    table.style.cssText = `
      width: 100%;
      border-collapse: collapse;
      background: rgba(255, 255, 255, 0.95);
      border-radius: 6px;
      overflow: hidden;
      table-layout: fixed;
    `;

    const theadRow = document.createElement('tr');
    theadRow.style.cssText = 'background: rgba(102, 126, 234, 0.2);';
    
    requiredConstants.forEach(item => {
      const th = document.createElement('th');
      th.style.cssText = `
        padding: 6px 2px;
        text-align: center;
        font-weight: 700;
        font-size: 11px;
        color: #667eea;
        width: ${100 / requiredConstants.length}%;
      `;
      th.textContent = item.label;
      theadRow.appendChild(th);
    });
    
    const tbodyRow = document.createElement('tr');
    
    requiredConstants.forEach(item => {
      const td = document.createElement('td');
      td.style.cssText = `
        padding: 6px 2px;
        text-align: center;
        font-weight: 700;
        color: #333;
        font-size: 12px;
        transition: background 0.2s;
      `;
      td.textContent = item.constant;
      td.onmouseenter = () => td.style.background = 'rgba(102, 126, 234, 0.1)';
      td.onmouseleave = () => td.style.background = 'transparent';
      tbodyRow.appendChild(td);
    });

    const thead = document.createElement('thead');
    thead.appendChild(theadRow);
    
    const tbody = document.createElement('tbody');
    tbody.appendChild(tbodyRow);

    table.appendChild(thead);
    table.appendChild(tbody);
    
    const note = document.createElement('div');
    note.style.cssText = `
      margin-top: 8px;
      font-size: 10px;
      text-align: center;
      font-style: italic;
      color: #666;
    `;
    note.textContent = '※ 基于当前总PTT计算';

    cardInner.appendChild(title);
    cardInner.appendChild(subtitle);
    cardInner.appendChild(table);
    cardInner.appendChild(note);
    cardContainer.appendChild(cardInner);

    return cardContainer;
  }

  function insertPTTIncreaseCard(currentPTT, best30PTTs, recent10PTTs) {
    try {
      if (document.querySelector('.arcaea-ptt-increase-card')) {
        return;
      }

      const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
      if (cardLists.length === 0) return;

      const cardList = cardLists[0];
      const firstCard = cardList.querySelector('[data-v-337fbd7d].card, div[data-v-337fbd7d].card');
      
      if (!firstCard) return;

      const pttCard = createPTTIncreaseCard(currentPTT, best30PTTs, recent10PTTs);
      cardList.insertBefore(pttCard, firstCard);
    } catch (error) {
      console.error('[Arcaea Helper] 插入PTT增长卡片失败:', error);
    }
  }

  function addSectionDivider(cardList) {
    if (cardList.querySelector('.arcaea-section-divider')) {
      return;
    }

    try {
      const cardContainers = cardList.querySelectorAll('[data-v-337fbd7d].card, div[data-v-337fbd7d].card');
      
      if (cardContainers.length > 30) {
        const divider = document.createElement('div');
        divider.className = 'arcaea-section-divider';
        
        const thirtyFirstContainer = cardContainers[30];
        cardList.insertBefore(divider, thirtyFirstContainer);
      }
    } catch (error) {
      console.error('[Arcaea Helper] 添加分隔线失败:', error);
    }
  }

  function processAllCards() {
    try {
      const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
      
      let totalBest30 = 0;
      let totalRecent10 = 0;
      const best30PTTs = [];
      const recent10PTTs = [];
      
      cardLists.forEach((cardList, listIndex) => {
        const allElements = cardList.querySelectorAll('[data-v-b3942f14].card, div[data-v-b3942f14].card');
        
        allElements.forEach((card, cardIndex) => {
          if (cardIndex < 30) {
            const ptt = processCard(card, cardIndex + 1, false, null);
            if (ptt !== null) {
              best30PTTs.push(ptt);
            }
            totalBest30++;
          } else if (cardIndex < 40) {
            const recentIndex = cardIndex - 29;
            const ptt = processCard(card, recentIndex, true, null);
            if (ptt !== null) {
              recent10PTTs.push(ptt);
            }
            totalRecent10++;
          } else {
            processCard(card, null, false, null);
          }
        });
        
        addSectionDivider(cardList);
      });
      
      if (best30PTTs.length > 0 || recent10PTTs.length > 0) {
        const best30Sum = best30PTTs.reduce((sum, ptt) => sum + ptt, 0);
        const recent10Sum = recent10PTTs.reduce((sum, ptt) => sum + ptt, 0);
        const totalPTT = (best30Sum + recent10Sum) / 40;
        
        // 计算B30和R10平均值
        const best30Avg = best30PTTs.length > 0 
          ? best30PTTs.reduce((sum, ptt) => sum + ptt, 0) / best30PTTs.length 
          : 0;
        const recent10Avg = recent10PTTs.length > 0 
          ? recent10PTTs.reduce((sum, ptt) => sum + ptt, 0) / recent10PTTs.length 
          : 0;
        
        console.log(`[Arcaea Helper] 计算的总PTT: ${totalPTT.toFixed(4)}`);
        
        displayTotalPTT(totalPTT, best30PTTs, recent10PTTs);
        insertPTTIncreaseCard(totalPTT, best30PTTs, recent10PTTs);
        
        // 在PTT增长卡片插入后，添加B30/R10信息
        addB30R10InfoToFirstCard(best30Avg, recent10Avg);
        
        addTargetScoresToAllCards(totalPTT);
      }
    } catch (error) {
      console.error('[Arcaea Helper] 处理卡片列表失败:', error);
    }
  }

  function addTargetScoresToAllCards(totalPTT) {
    try {
      const allCards = document.querySelectorAll('[data-v-b3942f14].card, div[data-v-b3942f14].card');
      
      allCards.forEach((cardElement) => {
        if (cardElement.querySelector('.arcaea-target-score')) {
          return;
        }
        
        const { title: songTitle, score } = getSongTitleAndScoreFromCard(cardElement);
        if (!songTitle || score === null) return;
        
        const difficulty = getDifficultyFromElement(cardElement);
        if (difficulty === null) return;
        
        const constant = dataLoader.getChartConstant(songTitle, difficulty, false);
        if (constant === null) return;
        
        if (currentSettings.showTargetScore) {
          addTargetScore(cardElement, constant, score, totalPTT);
        }
      });
    } catch (error) {
      console.error('[Arcaea Helper] 添加目标分数失败:', error);
    }
  }

  function collectExportData() {
    try {
      // 收集玩家信息
      const usernameElement = document.querySelector('.username, [class*="username"]');
      const username = usernameElement ? usernameElement.textContent.trim() : 'Unknown Player';
      
      // 获取PTT信息
      const pttElement = document.querySelector('.arcaea-total-ptt');
      let totalPTT = null;
      let best30Avg = null;
      let recent10Avg = null;
      
      if (pttElement) {
        const pttText = pttElement.textContent;
        // 新格式：只有精确PTT值
        const pttMatch = pttText.match(/\(([\d.]+)\)/);
        if (pttMatch) {
          totalPTT = parseFloat(pttMatch[1]);
        }
      }
      
      // 从第一个卡片获取B30和R10信息
      const b30r10Info = document.querySelector('.arcaea-b30r10-info');
      if (b30r10Info) {
        const b30Match = b30r10Info.textContent.match(/B30:\s*([\d.]+)/);
        const r10Match = b30r10Info.textContent.match(/R10:\s*([\d.]+)/);
        if (b30Match) best30Avg = parseFloat(b30Match[1]);
        if (r10Match) recent10Avg = parseFloat(r10Match[1]);
      }
      
      // 收集所有卡片数据
      const best30Cards = [];
      const recent10Cards = [];
      
      const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
      
      cardLists.forEach((cardList) => {
        const allCards = cardList.querySelectorAll('[data-v-b3942f14].card, div[data-v-b3942f14].card');
        
        allCards.forEach((card, index) => {
          // 跳过 PTT 增长卡片（.arcaea-ptt-increase-card）
          if (card.classList.contains('arcaea-ptt-increase-card')) {
            return;
          }
          
          const cardData = extractCardData(card);
          if (cardData) {
            // 重新计算实际的卡片索引（不包括特殊卡片）
            const actualIndex = best30Cards.length + recent10Cards.length;
            
            if (actualIndex < 30) {
              best30Cards.push({ ...cardData, rank: actualIndex + 1 });
            } else if (actualIndex < 40) {
              recent10Cards.push({ ...cardData, rank: actualIndex - 29 });
            }
          }
        });
      });
      
      return {
        player: {
          username,
          totalPTT,
          best30Avg,
          recent10Avg,
          exportDate: new Date().toISOString()
        },
        best30: best30Cards,
        recent10: recent10Cards
      };
    } catch (error) {
      console.error('[Arcaea Helper] 收集导出数据失败:', error);
      return null;
    }
  }

  function extractCardData(cardElement) {
    try {
      // 获取歌曲信息
      const { title: songTitle, score } = getSongTitleAndScoreFromCard(cardElement);
      if (!songTitle) return null;
      
      // 获取难度
      const difficulty = getDifficultyFromElement(cardElement);
      if (difficulty === null) return null;
      
      const difficultyNames = ['PST', 'PRS', 'FTR', 'BYD', 'ETR'];
      const difficultyName = difficultyNames[difficulty] || 'UNKNOWN';
      
      // 获取定数
      const constant = dataLoader.getChartConstant(songTitle, difficulty, false);
      
      // 获取PTT
      const pttElement = cardElement.querySelector('.arcaea-play-ptt');
      let playPTT = null;
      if (pttElement) {
        const pttText = pttElement.textContent.trim();
        playPTT = parseFloat(pttText);
      }
      
      // 获取曲绘URL - 查找实际的封面图片
      let coverUrl = null;
      
      // 首先查找所有元素的背景图片（优先，因为曲绘通常作为背景）
      const allElements = cardElement.querySelectorAll('*');
      for (const el of allElements) {
        const bgStyle = window.getComputedStyle(el).backgroundImage;
        if (bgStyle && bgStyle !== 'none') {
          const urlMatch = bgStyle.match(/url\(["']?([^"']+)["']?\)/);
          if (urlMatch && urlMatch[1] && 
              !urlMatch[1].startsWith('data:image/svg') && 
              (urlMatch[1].includes('.jpg') || urlMatch[1].includes('.png') || 
               urlMatch[1].includes('.webp') || urlMatch[1].includes('img'))) {
            coverUrl = urlMatch[1];
            break;
          }
        }
      }
      
      // 如果还是没找到，尝试img标签
      if (!coverUrl) {
        const imgs = cardElement.querySelectorAll('img');
        for (const img of imgs) {
          if (img.src && !img.src.startsWith('data:image/svg') && 
              (img.src.includes('.jpg') || img.src.includes('.png') || 
               img.src.includes('.webp') || img.src.includes('img'))) {
            coverUrl = img.src;
            break;
          }
        }
      }
      
      return {
        songTitle,
        difficulty: difficultyName,
        difficultyIndex: difficulty,
        score,
        constant,
        playPTT,
        coverUrl
      };
    } catch (error) {
      console.error('[Arcaea Helper] 提取卡片数据失败:', error);
      return null;
    }
  }

  function cleanup() {
    if (domObserver) {
      domObserver.disconnect();
      domObserver = null;
    }
    
    processedElements = new WeakSet();
    debugFirstCard = true;
  }

  function observeDOMChanges() {
    if (domObserver) {
      domObserver.disconnect();
    }

    domObserver = new MutationObserver((mutations) => {
      let shouldProcess = false;
      
      for (const mutation of mutations) {
        if (mutation.addedNodes.length > 0) {
          shouldProcess = true;
          break;
        }
      }
      
      if (shouldProcess) {
        setTimeout(processAllCards, 500);
      }
    });

    domObserver.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  function init(isReInit = false) {
    if (isReInit) {
      cleanup();
    }
    
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => {
        setTimeout(() => {
          processAllCards();
          observeDOMChanges();
        }, 1000);
      });
    } else {
      setTimeout(() => {
        processAllCards();
        observeDOMChanges();
      }, 1000);
    }
  }

  function observeUrlChanges() {
    setInterval(() => {
      const newUrl = window.location.href;
      if (newUrl !== currentUrl) {
        currentUrl = newUrl;
        
        if (newUrl.includes('/profile/potential')) {
          setTimeout(() => init(true), 500);
        } else {
          cleanup();
        }
      }
    }, 1000);
  }

  function interceptHistoryChanges() {
    const originalPushState = history.pushState;
    const originalReplaceState = history.replaceState;
    
    history.pushState = function() {
      originalPushState.apply(this, arguments);
      setTimeout(() => {
        const newUrl = window.location.href;
        if (newUrl !== currentUrl) {
          currentUrl = newUrl;
          if (newUrl.includes('/profile/potential')) {
            init(true);
          } else {
            cleanup();
          }
        }
      }, 500);
    };
    
    history.replaceState = function() {
      originalReplaceState.apply(this, arguments);
      setTimeout(() => {
        const newUrl = window.location.href;
        if (newUrl !== currentUrl) {
          currentUrl = newUrl;
          if (newUrl.includes('/profile/potential')) {
            init(true);
          } else {
            cleanup();
          }
        }
      }, 500);
    };
    
    window.addEventListener('popstate', () => {
      setTimeout(() => {
        const newUrl = window.location.href;
        if (newUrl !== currentUrl) {
          currentUrl = newUrl;
          if (newUrl.includes('/profile/potential')) {
            init(true);
          } else {
            cleanup();
          }
        }
      }, 500);
    });
  }

  init(false);
  observeUrlChanges();
  interceptHistoryChanges();
})();
