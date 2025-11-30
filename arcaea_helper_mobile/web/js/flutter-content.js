// Arcaea Helper - Flutter WebView Content Script
// 简化版内容脚本，适配 Flutter InAppWebView 环境

(async function() {
  'use strict';

  console.log('[Arcaea Helper Flutter] 🚀 脚本已加载');

  // 从 window 获取设置（由 Flutter 注入）
  const currentSettings = window.arcaeaSettings || {
    showCharts: false,
    showConstant: true,
    showPTT: true,
    showTargetScore: true,
    showDownloadButtons: true
  };

  const dataLoader = window.arcaeaDataLoader;
  if (!dataLoader) {
    console.error('[Arcaea Helper Flutter] ❌ 数据加载器未初始化');
    return;
  }

  let processedElements = new WeakSet();

  // 应用设置
  function applySettings(settings) {
    console.log('[Arcaea Helper] 应用设置:', settings);
    Object.assign(currentSettings, settings);
    
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
    
    // 清除已处理标记，重新处理页面
    processedElements = new WeakSet();
    const processedCards = document.querySelectorAll('.arcaea-processed');
    processedCards.forEach(card => {
      card.classList.remove('arcaea-processed');
      card.classList.remove('arcaea-indexed');
      // 清除已添加的元素
      card.querySelectorAll('.arcaea-chart-info, .arcaea-target-score, .arcaea-card-index').forEach(el => el.remove());
    });
    
    // 清除总PTT和推分卡片
    document.querySelectorAll('.arcaea-total-ptt, .arcaea-ptt-increase-card, .arcaea-section-divider').forEach(el => el.remove());
    
    // 重新处理（只在已经处理过一次的情况下）
    if (hasProcessedOnce) {
      setTimeout(processAllCards, 300);
    }
  }

  // 应用初始样式设置（不触发处理）
  function applyInitialStyles() {
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
      div[data-v-337fbd7d].diagram-section {
        display: none !important;
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
      [data-v-337fbd7d].download-container {
        display: none !important;
      }
    `;
  }

  function showDownloadButtons() {
    const styleElement = document.getElementById('arcaea-helper-download-style');
    if (styleElement) {
      styleElement.remove();
    }
  }

  // 等待 DOM 中有实际内容再处理
  function waitForContent(callback, maxRetries = 10, retryDelay = 500) {
    let retries = 0;
    
    function check() {
      const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
      const hasCards = Array.from(cardLists).some(list => 
        list.querySelectorAll('[data-v-b3942f14].card').length > 0
      );
      
      if (hasCards) {
        console.log('[Arcaea Helper] ✅ 检测到页面内容，开始处理');
        callback();
      } else if (retries < maxRetries) {
        retries++;
        console.log(`[Arcaea Helper] ⏳ 等待页面内容加载 (${retries}/${maxRetries})`);
        setTimeout(check, retryDelay);
      } else {
        console.log('[Arcaea Helper] ⚠️ 超过最大重试次数，强制处理');
        callback();
      }
    }
    
    check();
  }

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

  function addChartConstantAndPTT(titleElement, constant, score = null) {
    if (!titleElement || processedElements.has(titleElement)) return;
    if (titleElement.parentElement?.querySelector('.arcaea-chart-info')) return;

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

      if (currentSettings.showPTT && score !== null) {
        const playPTT = window.ArcaeaCalculator.calculatePlayPTT(score, constant);
        if (playPTT !== null) {
          const pttSpan = document.createElement('span');
          pttSpan.className = 'arcaea-play-ptt';
          pttSpan.textContent = ` ${window.ArcaeaCalculator.formatPTT(playPTT)}`;
          pttSpan.style.color = '#667eea';
          pttSpan.style.fontSize = '0.9em';
          pttSpan.style.fontWeight = '700';
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
        }
      }
      
      processedElements.add(titleElement);
    } catch (error) {
      console.error('[Arcaea Helper] 添加定数显示失败:', error);
    }
  }

  function addTargetScore(cardElement, constant, currentScore, totalPTT) {
    try {
      if (!currentSettings.showTargetScore) return;
      if (cardElement.querySelector('.arcaea-target-score')) return;
      
      const scoreElements = cardElement.querySelectorAll('.ex-main, [class*="ex-main"]');
      if (scoreElements.length === 0) return;
      
      const scoreElement = scoreElements[0];
      const targetScore = window.ArcaeaCalculator.calculateTargetScore(constant, currentScore, totalPTT);
      
      const targetDiv = document.createElement('div');
      targetDiv.className = 'arcaea-target-score';
      targetDiv.style.fontSize = '0.85em';
      targetDiv.style.fontWeight = '600';
      targetDiv.style.marginTop = '2px';
      targetDiv.style.textAlign = 'left';
      targetDiv.style.display = 'block';
      targetDiv.style.width = '100%';
      targetDiv.style.color = targetScore !== null ? '#10b981' : '#ef4444';
      targetDiv.textContent = targetScore !== null 
        ? `>> ${window.ArcaeaCalculator.formatScore(targetScore)}`
        : '无法推分';
      
      const experienceContainer = scoreElement.closest('.experince, [class*="experince"]');
      if (experienceContainer) {
        experienceContainer.appendChild(targetDiv);
      } else {
        scoreElement.parentElement?.appendChild(targetDiv);
      }
    } catch (error) {
      console.error('[Arcaea Helper] 添加目标分数失败:', error);
    }
  }

  function addCardIndex(cardElement, index, isRecent = false) {
    if (cardElement.querySelector('.arcaea-card-index')) return;
    if (cardElement.classList.contains('arcaea-indexed')) return;
    
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

      const titleElement = Array.from(cardElement.querySelectorAll('span'))
        .find(el => el.textContent?.trim() === songTitle);
      
      let playPTT = null;
      if (titleElement) {
        addChartConstantAndPTT(titleElement, constant, score);
        if (score !== null) {
          playPTT = window.ArcaeaCalculator.calculatePlayPTT(score, constant);
          
          // 如果有总PTT，添加目标分数
          if (totalPTT !== null) {
            addTargetScore(cardElement, constant, score, totalPTT);
          }
        }
      }

      // 添加序号
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

  function displayTotalPTT(totalPTT) {
    try {
      if (document.querySelector('.arcaea-total-ptt')) return;
      
      const usernameElements = document.querySelectorAll('.username, [class*="username"]');
      if (usernameElements.length === 0) return;

      const usernameElement = usernameElements[0];
      const pttSpan = document.createElement('span');
      pttSpan.className = 'arcaea-total-ptt';
      pttSpan.textContent = ` (PTT: ${totalPTT.toFixed(4)})`;
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
      }
    } catch (error) {
      console.error('[Arcaea Helper] 显示总PTT失败:', error);
    }
  }

  function createPTTIncreaseCard(currentPTT, best30PTTs, recent10PTTs) {
    try {
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

      cardInner.innerHTML = `
        <div style="font-weight: 700; font-size: 14px; margin-bottom: 4px; text-align: center; color: #333;">
          使显示 PTT +0.01 所需最低谱面定数
        </div>
        <div style="font-size: 11px; margin-bottom: 12px; text-align: center; color: #555;">
          当前显示: ${displayedPTT.toFixed(2)} → 目标: ${targetPTT.toFixed(2)}
        </div>
        <table style="width: 100%; border-collapse: collapse; background: rgba(255,255,255,0.95); border-radius: 6px; overflow: hidden;">
          <thead>
            <tr style="background: rgba(102,126,234,0.2);">
              ${requiredConstants.map(item => `
                <th style="padding: 6px 2px; text-align: center; font-weight: 700; font-size: 11px; color: #667eea;">
                  ${item.label}
                </th>
              `).join('')}
            </tr>
          </thead>
          <tbody>
            <tr>
              ${requiredConstants.map(item => `
                <td style="padding: 6px 2px; text-align: center; font-weight: 700; color: #333; font-size: 12px;">
                  ${item.constant}
                </td>
              `).join('')}
            </tr>
          </tbody>
        </table>
        <div style="margin-top: 8px; font-size: 10px; text-align: center; font-style: italic; color: #666;">
          ※ 基于当前总PTT计算
        </div>
      `;

      cardContainer.appendChild(cardInner);
      return cardContainer;
    } catch (error) {
      console.error('[Arcaea Helper] 创建PTT增长卡片失败:', error);
      return null;
    }
  }

  function insertPTTIncreaseCard(currentPTT, best30PTTs, recent10PTTs) {
    try {
      if (document.querySelector('.arcaea-ptt-increase-card')) return;

      const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
      if (cardLists.length === 0) return;

      const cardList = cardLists[0];
      const firstCard = cardList.querySelector('[data-v-337fbd7d].card');
      if (!firstCard) return;

      const pttCard = createPTTIncreaseCard(currentPTT, best30PTTs, recent10PTTs);
      if (pttCard) {
        cardList.insertBefore(pttCard, firstCard);
      }
    } catch (error) {
      console.error('[Arcaea Helper] 插入PTT增长卡片失败:', error);
    }
  }

  function addSectionDivider(cardList) {
    if (cardList.querySelector('.arcaea-section-divider')) return;

    try {
      const cardContainers = cardList.querySelectorAll('[data-v-337fbd7d].card');
      if (cardContainers.length > 30) {
        const divider = document.createElement('div');
        divider.className = 'arcaea-section-divider';
        cardList.insertBefore(divider, cardContainers[30]);
      }
    } catch (error) {
      console.error('[Arcaea Helper] 添加分隔线失败:', error);
    }
  }

  function processAllCards() {
    try {
      const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
      const best30PTTs = [];
      const recent10PTTs = [];
      
      console.log(`[Arcaea Helper] 找到 ${cardLists.length} 个卡片列表`);
      
      // 第一轮：收集PTT数据
      cardLists.forEach((cardList) => {
        const allElements = cardList.querySelectorAll('[data-v-b3942f14].card');
        console.log(`[Arcaea Helper] 找到 ${allElements.length} 个卡片`);
        
        allElements.forEach((card, cardIndex) => {
          if (cardIndex < 30) {
            const ptt = processCard(card, cardIndex + 1, false, null);
            if (ptt !== null) best30PTTs.push(ptt);
          } else if (cardIndex < 40) {
            const ptt = processCard(card, cardIndex - 29, true, null);
            if (ptt !== null) recent10PTTs.push(ptt);
          }
        });
        
        addSectionDivider(cardList);
      });
      
      if (best30PTTs.length > 0 || recent10PTTs.length > 0) {
        const best30Sum = best30PTTs.reduce((sum, ptt) => sum + ptt, 0);
        const recent10Sum = recent10PTTs.reduce((sum, ptt) => sum + ptt, 0);
        const totalPTT = (best30Sum + recent10Sum) / 40;
        
        console.log(`[Arcaea Helper] Best 30: ${best30PTTs.length}首, 总和: ${best30Sum.toFixed(4)}`);
        console.log(`[Arcaea Helper] Recent 10: ${recent10PTTs.length}首, 总和: ${recent10Sum.toFixed(4)}`);
        console.log(`[Arcaea Helper] 计算的总PTT: ${totalPTT.toFixed(4)}`);
        
        displayTotalPTT(totalPTT);
        insertPTTIncreaseCard(totalPTT, best30PTTs, recent10PTTs);
        
        // 第二轮：添加目标分数
        cardLists.forEach((cardList) => {
          const allElements = cardList.querySelectorAll('[data-v-b3942f14].card');
          allElements.forEach((card) => {
            if (card.querySelector('.arcaea-target-score')) return;
            
            const { title, score } = getSongTitleAndScoreFromCard(card);
            if (!title || score === null) return;
            
            const difficulty = getDifficultyFromElement(card);
            if (difficulty === null) return;
            
            const constant = dataLoader.getChartConstant(title, difficulty, false);
            if (constant === null) return;
            
            addTargetScore(card, constant, score, totalPTT);
          });
        });
        
        console.log('[Arcaea Helper] ✅ 所有卡片处理完成');
      } else {
        console.log('[Arcaea Helper] ℹ️ 没有找到有效的PTT数据');
      }
    } catch (error) {
      console.error('[Arcaea Helper] 处理卡片失败:', error);
      console.error('[Arcaea Helper] 错误堆栈:', error.stack);
    }
  }

  // ==================== 初始化和接口暴露 ====================
  
  // 防止重复处理的标志
  let isProcessing = false;
  let hasProcessedOnce = false;

  // 暴露给 Flutter 的接口
  window.applySettings = applySettings;
  
  window.triggerProcessAllCards = function() {
    if (isProcessing) {
      console.log('[Arcaea Helper] 正在处理中，跳过重复触发');
      return;
    }
    
    isProcessing = true;
    console.log('[Arcaea Helper] 手动触发处理所有卡片');
    
    waitForContent(() => {
      processAllCards();
      isProcessing = false;
      hasProcessedOnce = true;
      
      // 首次处理完成后才启动 MutationObserver
      if (!window.arcaeaMutationObserverStarted) {
        window.arcaeaMutationObserverStarted = true;
        startMutationObserver();
        console.log('[Arcaea Helper] MutationObserver 已启动');
      }
    }, 10, 500);
  };
  
  // MutationObserver - 延迟启动，只在首次处理完成后
  function startMutationObserver() {
    const observer = new MutationObserver((mutations) => {
      if (isProcessing) return;
      
      let shouldProcess = false;
      for (const mutation of mutations) {
        if (mutation.addedNodes.length > 0) {
          shouldProcess = true;
          break;
        }
      }
      if (shouldProcess) {
        console.log('[Arcaea Helper] 检测到DOM变化，500ms后重新处理');
        setTimeout(() => {
          if (!isProcessing) {
            isProcessing = true;
            processAllCards();
            isProcessing = false;
          }
        }, 500);
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  // 应用初始样式（不触发卡片处理）
  applyInitialStyles();

  // 标记脚本已就绪（所有函数定义完成后才设置）
  window.arcaeaHelperReady = true;
  
  // 不自动初始化，等待 Flutter 主动触发
  console.log('[Arcaea Helper Flutter] ✅ 脚本已就绪，等待 Flutter 触发初始化');
})();