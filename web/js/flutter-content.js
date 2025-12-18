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
      let titleElement = null;

      // 1. 提取标题 - 增加更多可能的选择器
      const titleSelectors = [
        'span.no-overflow',
        '.title .no-overflow',
        '.title span',
        '.song-title',
        '.song-name',
        '.name',
        '[class*="title"]',
        '[class*="name"]'
      ];
      
      for (const selector of titleSelectors) {
        const elements = cardElement.querySelectorAll(selector);
        for (const el of elements) {
          const text = el.textContent.trim();
          // 排除掉一些明显的干扰项
          if (text.length > 0 && 
              text.length < 60 && 
              text !== 'Title' && 
              text !== '标题' &&
              !text.match(/^\d+$/) &&
              !text.includes('潜力值') &&
              !text.includes('所需最低')) {
            title = text.replace(/\s*\([\d.]+\)\s*$/, '').trim();
            titleElement = el;
            break;
          }
        }
        if (title) break;
      }

      // 2. 提取分数 - 采用更激进的扫描策略
      // 优先尝试标准类名
      const scoreElements = cardElement.querySelectorAll('.ex-main, [class*="ex-main"], .score, [class*="score"]');
      let potentialScores = [];
      
      for (const el of scoreElements) {
        const text = el.textContent.trim();
        const match = text.match(/(\d{1,3}(,\d{3})*|\d{7,8})/);
        if (match) {
          const num = parseInt(match[0].replace(/,/g, ''), 10);
          if (num >= 5000000 && num <= 10002000) {
            potentialScores.push(num);
          }
        }
      }
      
      // 如果没找到，扫描所有文本节点
      if (potentialScores.length === 0) {
        const walker = document.createTreeWalker(cardElement, NodeFilter.SHOW_TEXT, null, false);
        let node;
        while (node = walker.nextNode()) {
          const text = node.textContent.trim();
          // 排除日期格式
          if (text.includes('/') || text.includes(':')) continue;
          
          const match = text.match(/(\d{1,3}(,\d{3})*|\d{7,8})/);
          if (match) {
            const num = parseInt(match[0].replace(/,/g, ''), 10);
            if (num >= 5000000 && num <= 10002000) {
              potentialScores.push(num);
            }
          }
        }
      }
      
      if (potentialScores.length > 0) {
        // 取最大的那个数字作为分数（防止误抓到连击数等）
        score = Math.max(...potentialScores);
      }
      
      // 特殊调试日志
      if (title && title.toUpperCase().includes('NULL')) {
        console.log(`[Arcaea Helper] 识别到特殊歌曲: "${title}", 分数: ${score}`);
      }
      
      return { title, score, titleElement };
    } catch (error) {
      console.error('[Arcaea Helper] 获取歌曲信息失败:', error);
    }
    return { title: null, score: null, titleElement: null };
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

  // 检查是否为真正的歌曲卡片
  function isSongCard(cardElement) {
    const text = cardElement.innerText || "";
    // 歌曲卡片必须包含难度标识
    const hasDifficulty = /FTR|BYD|PRS|PST|ETR|FUTURE|BEYOND|PRESENT|PAST|ETERNAL/i.test(text);
    // 歌曲卡片必须包含分数格式 (7-8位数字，可能带逗号)
    const hasScore = /\d{1,3}(,\d{3}){2}/.test(text) || /\d{7,8}/.test(text);
    return hasDifficulty && hasScore && text.length > 20;
  }

  function processCard(cardElement, index = null, isRecent = false, totalPTT = null) {
    if (cardElement.classList.contains('arcaea-processed')) {
      return cardElement._arcaeaPlayPTT || null;
    }
    if (processedElements.has(cardElement)) return null;

    try {
      const { title: songTitle, score, titleElement } = getSongTitleAndScoreFromCard(cardElement);
      if (!songTitle || score === null) {
        if (songTitle && score === null) {
          console.log(`[Arcaea Helper] 跳过歌曲 (无分数): ${songTitle}`);
        }
        return null;
      }

      const difficulty = getDifficultyFromElement(cardElement);
      if (difficulty === null) return null;

      const constant = dataLoader.getChartConstant(songTitle, difficulty, false);
      if (constant === null) return null;

      // 存储数据供第二轮使用
      cardElement._arcaeaTitle = songTitle;
      cardElement._arcaeaScore = score;
      cardElement._arcaeaConstant = constant;

      let playPTT = window.ArcaeaCalculator.calculatePlayPTT(score, constant);
      cardElement._arcaeaPlayPTT = playPTT;

      if (titleElement) {
        addChartConstantAndPTT(titleElement, constant, score);
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

  function processAllCards() {
    try {
      const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
      const best30PTTs = [];
      const recent10PTTs = [];

      cardLists.forEach((cardList) => {
        const allElements = Array.from(cardList.querySelectorAll('[data-v-b3942f14].card'));
        const songCards = allElements.filter(isSongCard);

        console.log(`[Arcaea Helper] 页面卡片总数: ${allElements.length}, 识别为歌曲数: ${songCards.length}`);

        // 调试：打印前若干张卡片的判定细节
        const sampleCount = Math.min(12, allElements.length);
        for (let i = 0; i < sampleCount; i++) {
          const card = allElements[i];
          const text = card.innerText || '';
          const hasDifficulty = /FTR|BYD|PRS|PST|ETR|FUTURE|BEYOND|PRESENT|PAST|ETERNAL/i.test(text);
          const hasScore = /\d{1,3}(,\d{3}){2}/.test(text) || /\d{7,8}/.test(text);
          const head = text.replace(/\s+/g, ' ').slice(0, 120);
          console.log(`[Arcaea Helper][Card#${i + 1}] isSongCard=${hasDifficulty && hasScore} hasDiff=${hasDifficulty} hasScore=${hasScore} text="${head}${text.length > 120 ? '…' : ''}"`);
        }

        songCards.forEach((card, idx) => {
          if (best30PTTs.length < 30) {
            const ptt = processCard(card, best30PTTs.length + 1, false, null);
            if (ptt !== null) {
              best30PTTs.push(ptt);
            } else {
              console.log(`[Arcaea Helper] 歌曲卡片处理失败: idx=${idx + 1} 目标=B${best30PTTs.length + 1}`);
            }
          } else if (recent10PTTs.length < 10) {
            const ptt = processCard(card, recent10PTTs.length + 1, true, null);
            if (ptt !== null) {
              recent10PTTs.push(ptt);
            } else {
              console.log(`[Arcaea Helper] 歌曲卡片处理失败: idx=${idx + 1} 目标=R${recent10PTTs.length + 1}`);
            }
          }
        });

        addSectionDivider(cardList);
      });
      
      if (best30PTTs.length > 0 || recent10PTTs.length > 0) {
        const best30Sum = best30PTTs.reduce((sum, ptt) => sum + ptt, 0);
        const recent10Sum = recent10PTTs.reduce((sum, ptt) => sum + ptt, 0);
        const totalPTT = (best30Sum + recent10Sum) / 40;
        
        const best30Avg = best30PTTs.length > 0 ? best30Sum / best30PTTs.length : 0;
        const recent10Avg = recent10PTTs.length > 0 ? recent10Sum / recent10PTTs.length : 0;
        
        console.log(`[Arcaea Helper] Best 30: ${best30PTTs.length}首, Recent 10: ${recent10PTTs.length}首, 总PTT: ${totalPTT.toFixed(4)}`);
        
        displayTotalPTT(totalPTT, best30PTTs, recent10PTTs);
        insertPTTIncreaseCard(totalPTT, best30PTTs, recent10PTTs);
        addB30R10InfoToFirstCard(best30Avg, recent10Avg);
        
        // 第二轮：添加目标分数
        cardLists.forEach((cardList) => {
          const songCards = Array.from(cardList.querySelectorAll('[data-v-b3942f14].card')).filter(isSongCard);
          songCards.forEach((card) => {
            if (card.querySelector('.arcaea-target-score')) return;
            if (card._arcaeaConstant && card._arcaeaScore) {
              addTargetScore(card, card._arcaeaConstant, card._arcaeaScore, totalPTT);
            }
          });
        });
        
        console.log('[Arcaea Helper] ✅ 所有卡片处理完成');
      }
    } catch (error) {
      console.error('[Arcaea Helper] 处理过程出错:', error);
    }
  }

  function displayTotalPTT(totalPTT, best30PTTs, recent10PTTs) {
    try {
      if (document.querySelector('.arcaea-total-ptt')) return;
      
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
        const allElements = Array.from(cardList.querySelectorAll('[data-v-b3942f14].card'));
        
        // 过滤掉非歌曲卡片（如顶部的 PTT 变动卡片）
        const songCards = allElements.filter((card, idx) => {
          const text = card.innerText || "";
          const isPttCard = (text.includes('潜力值') || text.includes('Potential')) && 
                            (text.includes('+') || text.includes('-') || text.includes('标题'));
          
          if (isPttCard) {
            console.log(`[Arcaea Helper] 过滤掉第 ${idx + 1} 个卡片 (判定为 PTT 变动卡片)`);
          }
          return !isPttCard;
        });

        console.log(`[Arcaea Helper] 原始卡片数: ${allElements.length}, 过滤后歌曲卡片数: ${songCards.length}`);
        
        // 如果过滤后数量不对，尝试不进行过滤，但确保 processCard 能识别并跳过无效卡片
        const cardsToProcess = songCards.length >= 40 ? songCards : allElements;
        if (cardsToProcess === allElements && songCards.length < 40) {
          console.log('[Arcaea Helper] 过滤后歌曲不足 40，回退到处理所有原始卡片');
        }
        
        cardsToProcess.forEach((card, cardIndex) => {
          // 限制只处理前40个有效卡片
          if (best30PTTs.length < 30) {
            const ptt = processCard(card, best30PTTs.length + 1, false, null);
            if (ptt !== null) {
              best30PTTs.push(ptt);
            } else {
              console.log(`[Arcaea Helper] 第 ${cardIndex + 1} 个卡片处理返回 null (目标 B${best30PTTs.length + 1})`);
            }
          } else if (recent10PTTs.length < 10) {
            const ptt = processCard(card, recent10PTTs.length + 1, true, null);
            if (ptt !== null) {
              recent10PTTs.push(ptt);
            } else {
              console.log(`[Arcaea Helper] 第 ${cardIndex + 1} 个卡片处理返回 null (目标 R${recent10PTTs.length + 1})`);
            }
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
        
        console.log(`[Arcaea Helper] Best 30: ${best30PTTs.length}首, 总和: ${best30Sum.toFixed(4)}`);
        console.log(`[Arcaea Helper] Recent 10: ${recent10PTTs.length}首, 总和: ${recent10Sum.toFixed(4)}`);
        console.log(`[Arcaea Helper] 计算的总PTT: ${totalPTT.toFixed(4)}`);
        
        displayTotalPTT(totalPTT, best30PTTs, recent10PTTs);
        insertPTTIncreaseCard(totalPTT, best30PTTs, recent10PTTs);
        
        // 在PTT增长卡片插入后，添加B30/R10信息
        addB30R10InfoToFirstCard(best30Avg, recent10Avg);
        
        // 第二轮：添加目标分数
        cardLists.forEach((cardList) => {
          const allElements = Array.from(cardList.querySelectorAll('[data-v-b3942f14].card'));
          const songCards = allElements.filter(card => {
            const text = card.innerText || "";
            return !((text.includes('潜力值') || text.includes('Potential')) && (text.includes('+') || text.includes('-')));
          });

          songCards.forEach((card) => {
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
  let mutationTimeout = null;
  function startMutationObserver() {
    const observer = new MutationObserver((mutations) => {
      if (isProcessing) return;
      
      // 检查是否是有意义的DOM变化（排除我们自己添加的元素）
      let shouldProcess = false;
      for (const mutation of mutations) {
        if (mutation.addedNodes.length > 0) {
          // 检查新增的节点是否是卡片而不是我们添加的辅助元素
          for (const node of mutation.addedNodes) {
            if (node.nodeType === Node.ELEMENT_NODE) {
              // 跳过我们自己添加的元素
              if (node.classList && (
                node.classList.contains('arcaea-chart-info') ||
                node.classList.contains('arcaea-target-score') ||
                node.classList.contains('arcaea-card-index') ||
                node.classList.contains('arcaea-total-ptt') ||
                node.classList.contains('arcaea-ptt-increase-card') ||
                node.classList.contains('arcaea-section-divider') ||
                node.classList.contains('arcaea-b30r10-info')
              )) {
                continue;
              }
              
              // 如果是卡片容器或卡片列表，才触发重新处理
              if (node.classList && (
                node.classList.contains('card') ||
                node.classList.contains('card-list') ||
                node.querySelector && node.querySelector('[data-v-b3942f14].card')
              )) {
                shouldProcess = true;
                break;
              }
            }
          }
          if (shouldProcess) break;
        }
      }
      
      if (shouldProcess) {
        // 防抖：清除之前的定时器，避免频繁触发
        if (mutationTimeout) {
          clearTimeout(mutationTimeout);
        }
        
        mutationTimeout = setTimeout(() => {
          if (!isProcessing) {
            console.log('[Arcaea Helper] 检测到有效DOM变化，重新处理');
            isProcessing = true;
            processAllCards();
            isProcessing = false;
          }
          mutationTimeout = null;
        }, 1000); // 增加延迟到1秒，减少频繁触发
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  // 应用初始样式（不触发卡片处理）
  applyInitialStyles();

  // 导出B30/R10数据（供Flutter图片生成使用）
  window.exportB30R10Data = async function() {
    console.log('[Arcaea Helper] 开始导出B30/R10数据...');
    
    try {
      // 获取所有卡片
      const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
      if (cardLists.length === 0) {
        console.error('[Arcaea Helper] 未找到卡片列表');
        return null;
      }

      const best30Cards = [];
      const recent10Cards = [];
      const allCards = [];

      // 收集所有卡片
      let totalCardsProcessed = 0;
      let cardsSkipped = 0;
      
      cardLists.forEach((cardList, listIndex) => {
        const cards = cardList.querySelectorAll('[data-v-b3942f14].card');
        console.log(`[Arcaea Helper] 列表 ${listIndex}: 找到 ${cards.length} 张卡片`);

        cards.forEach((cardElement, cardIndex) => {
          totalCardsProcessed++;
          const { title, score } = getSongTitleAndScoreFromCard(cardElement);
          const difficulty = getDifficultyFromElement(cardElement);

          if (!title || score === null || difficulty === null) {
            cardsSkipped++;
            console.warn(`[Arcaea Helper] 跳过不完整的卡片 ${cardIndex}/${totalCardsProcessed}: title="${title}", score=${score}, difficulty=${difficulty}`);
            // 输出卡片的HTML结构用于调试
            console.log('[Arcaea Helper] 卡片HTML:', cardElement.outerHTML.substring(0, 500));
            return;
          }

          // 获取定数
          const constant = dataLoader ? dataLoader.getChartConstant(title, difficulty, false) : null;
          
          // 获取曲绘URL - 从DOM中提取实际的图片
          let coverUrl = null;
          
          // 首先查找所有元素的背景图片
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

          // 计算单曲PTT
          let playPTT = null;
          if (constant !== null) {
            if (score >= 10000000) {
              playPTT = constant + 2;
            } else if (score >= 9800000) {
              playPTT = constant + 1 + (score - 9800000) / 200000;
            } else {
              playPTT = constant + (score - 9500000) / 300000;
              if (playPTT < 0) playPTT = 0;
            }
          }

          const difficultyNames = ['PST', 'PRS', 'FTR', 'BYD', 'ETR'];
          const cardData = {
            songTitle: title,
            difficulty: difficultyNames[difficulty] || 'FTR',
            difficultyIndex: difficulty,
            score: score,
            constant: constant,
            playPTT: playPTT,
            coverUrl: coverUrl,
            rank: 0 // 稍后设置
          };

          allCards.push(cardData);
        });
      });

      console.log(`[Arcaea Helper] 导出统计: 处理了 ${totalCardsProcessed} 张卡片, 跳过了 ${cardsSkipped} 张, 成功收集 ${allCards.length} 张`);

      // 分割为Best 30和Recent 10
      // 前30张是Best 30，后面的是Recent 10
      for (let i = 0; i < allCards.length && i < 30; i++) {
        allCards[i].rank = i + 1;
        best30Cards.push(allCards[i]);
      }
      
      for (let i = 30; i < allCards.length; i++) {
        allCards[i].rank = i - 29; // R1, R2, ...
        recent10Cards.push(allCards[i]);
      }

      // 获取玩家信息
      let username = 'Player';
      let totalPTT = null;
      let best30Avg = null;
      let recent10Avg = null;

      // 尝试从页面获取玩家名
      const usernameElement = document.querySelector('.username, [class*="username"]');
      if (usernameElement) {
        username = usernameElement.textContent.trim();
      }

      // 尝试从页面获取PTT信息
      const pttElement = document.querySelector('.ptt, [class*="ptt"]');
      if (pttElement) {
        const pttText = pttElement.textContent.trim();
        const pttMatch = pttText.match(/([\d.]+)/);
        if (pttMatch) {
          totalPTT = parseFloat(pttMatch[1]);
        }
      }

      // 如果页面没有显示，计算B30和R10平均
      if (best30Cards.length > 0) {
        const validB30 = best30Cards.filter(c => c.playPTT !== null);
        if (validB30.length > 0) {
          best30Avg = validB30.reduce((sum, c) => sum + c.playPTT, 0) / validB30.length;
        }
      }

      if (recent10Cards.length > 0) {
        const validR10 = recent10Cards.filter(c => c.playPTT !== null);
        if (validR10.length > 0) {
          recent10Avg = validR10.reduce((sum, c) => sum + c.playPTT, 0) / validR10.length;
        }
      }

      // 如果总PTT未知但有B30和R10，计算总PTT
      if (totalPTT === null && best30Avg !== null && recent10Avg !== null) {
        totalPTT = (best30Avg * 30 + recent10Avg * 10) / 40;
      }

      const exportData = {
        player: {
          username: username,
          totalPTT: totalPTT,
          best30Avg: best30Avg,
          recent10Avg: recent10Avg,
          exportDate: new Date().toISOString()
        },
        best30: best30Cards,
        recent10: recent10Cards
      };

      console.log('[Arcaea Helper] ✅ 数据导出成功:', {
        username: username,
        best30Count: best30Cards.length,
        recent10Count: recent10Cards.length,
        totalPTT: totalPTT
      });

      // iOS WebView不支持返回大型对象，改为返回JSON字符串
      return JSON.stringify(exportData);
    } catch (error) {
      console.error('[Arcaea Helper] ❌ 导出数据失败:', error);
      return null;
    }
  };

  // 标记脚本已就绪（所有函数定义完成后才设置）
  window.arcaeaHelperReady = true;
  
  // 不自动初始化，等待 Flutter 主动触发
  console.log('[Arcaea Helper Flutter] ✅ 脚本已就绪，等待 Flutter 触发初始化');
})();