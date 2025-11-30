// Arcaea Online Chart Constant Helper - Content Script

(async function() {
  'use strict';

  console.log('[Arcaea Helper] 🚀 扩展已加载');
  console.log('[Arcaea Helper] 当前页面:', window.location.href);

  // 默认设置
  const DEFAULT_SETTINGS = {
    showCharts: false,  // 默认隐藏PTT变化图表
    showConstant: true,
    showPTT: true,
    showTargetScore: true,
    showDownloadButtons: true  // 默认显示下载按钮
  };

  // 当前设置
  let currentSettings = { ...DEFAULT_SETTINGS };

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
    
    // 应用图表显示设置
    if (currentSettings.showCharts) {
      showCharts();
    } else {
      hideCharts();
    }
    
    // 应用下载按钮显示设置
    if (currentSettings.showDownloadButtons) {
      showDownloadButtons();
    } else {
      hideDownloadButtons();
    }
  }

  // 隐藏图表
  function hideCharts() {
    // 添加自定义样式来隐藏图表
    let styleElement = document.getElementById('arcaea-helper-chart-style');
    if (!styleElement) {
      styleElement = document.createElement('style');
      styleElement.id = 'arcaea-helper-chart-style';
      document.head.appendChild(styleElement);
    }
    
    styleElement.textContent = `
      /* 隐藏 Best 30 和 Recent 10 的 PTT 变化图表 */
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
    
    console.log('[Arcaea Helper] ✅ 图表已隐藏');
  }

  // 显示图表
  function showCharts() {
    const styleElement = document.getElementById('arcaea-helper-chart-style');
    if (styleElement) {
      styleElement.remove();
    }
    console.log('[Arcaea Helper] ✅ 图表已显示');
  }

  // 隐藏下载按钮
  function hideDownloadButtons() {
    let styleElement = document.getElementById('arcaea-helper-download-style');
    if (!styleElement) {
      styleElement = document.createElement('style');
      styleElement.id = 'arcaea-helper-download-style';
      document.head.appendChild(styleElement);
    }
    
    styleElement.textContent = `
      /* 隐藏下载和背景选择按钮 */
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
    
    console.log('[Arcaea Helper] ✅ 下载按钮已隐藏');
  }

  // 显示下载按钮
  function showDownloadButtons() {
    const styleElement = document.getElementById('arcaea-helper-download-style');
    if (styleElement) {
      styleElement.remove();
    }
    console.log('[Arcaea Helper] ✅ 下载按钮已显示');
  }

  // 监听设置变化
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'SETTINGS_UPDATED') {
      console.log('[Arcaea Helper] 收到设置更新消息:', message.settings);
      currentSettings = message.settings;
      applySettings();
      
      // 重新处理卡片以应用新设置
      setTimeout(() => {
        processedElements = new WeakSet();
        processAllCards();
      }, 100);
    }
  });

  // 等待 arcaeaData 对象创建
  let waitCount = 0;
  while (!window.arcaeaData) {
    await new Promise(resolve => setTimeout(resolve, 100));
    waitCount++;
    if (waitCount > 50) {
      console.error('[Arcaea Helper] ❌ 等待 arcaeaData 超时（5秒）');
      console.error('[Arcaea Helper] 可能原因：data.js 未正确加载');
      return;
    }
  }
  console.log('[Arcaea Helper] ✅ arcaeaData 对象已创建');

  // 加载设置（这会立即应用图表显示/隐藏）
  await loadSettings();

  // 等待数据加载
  console.log('[Arcaea Helper] 正在初始化数据...');
  const dataLoaded = await window.arcaeaData.init();
  if (!dataLoaded) {
    console.error('[Arcaea Helper] ❌ 数据加载失败，扩展无法工作');
    console.error('[Arcaea Helper] 请检查 ChartConstant.json 和 Songlist.json 是否存在');
    return;
  }
  
  console.log('[Arcaea Helper] ✅ 数据初始化完成');
  console.log('[Arcaea Helper] ======================');
  console.log('[Arcaea Helper] 测试命令：');
  console.log('[Arcaea Helper] window.arcaeaData.getChartConstant("Tempestissimo", 3)');
  console.log('[Arcaea Helper] ======================');

  // 用于存储已处理的元素
  let processedElements = new WeakSet();
  
  // 调试标志 - 只在第一张卡片打印详细信息
  let debugFirstCard = true;

  // 当前页面 URL，用于检测路由变化
  let currentUrl = window.location.href;

  // DOM 观察器引用
  let domObserver = null;

  // 难度文本映射
  const difficultyTextMap = {
    'PST': 0,
    'PAST': 0,
    'PRS': 1,
    'PRESENT': 1,
    'FTR': 2,
    'FUTURE': 2,
    'BYD': 3,
    'BEYOND': 3,
    'ETR': 4,
    'ETERNAL': 4
  };

  /**
   * 从难度钻石元素中提取难度等级
   */
  function getDifficultyFromElement(cardElement) {
    try {
      // 查找难度标签 (PST/PRS/FTR/BYD/ETR)
      const difficultyLabels = cardElement.querySelectorAll('span.label, .label');
      
      for (const label of difficultyLabels) {
        const text = label.textContent.trim().toUpperCase();
        if (difficultyTextMap.hasOwnProperty(text)) {
          return difficultyTextMap[text];
        }
      }
      
      // 备用方法：查找任何包含难度文本的span
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

  /**
   * 从卡片元素中提取歌曲标题和分数
   * @returns {Object} {title: string, score: number}
   */
  function getSongTitleAndScoreFromCard(cardElement) {
    try {
      let title = null;
      let score = null;

      // 根据DOM结构，歌曲标题在 class="no-overflow" 的第一个span中
      // 第一个no-overflow是标题，第二个是艺术家
      const noOverflowSpans = cardElement.querySelectorAll('span.no-overflow');
      
      if (noOverflowSpans.length > 0) {
        title = noOverflowSpans[0].textContent.trim();
        if (title && title !== 'Title') { // 排除字段名
          // 去除已显示的定数 (如 "Felis (10.4)" -> "Felis")
          title = title.replace(/\s*\([\d.]+\)\s*$/, '').trim();
        } else {
          title = null;
        }
      }
      
      // 提取分数：查找 class="ex-main" 的元素
      const exMainElements = cardElement.querySelectorAll('.ex-main, [class*="ex-main"]');
      for (const exMain of exMainElements) {
        const text = exMain.textContent.trim();
        // 分数格式: "EX 09,865,701" 或 "AA 09,800,000"
        const scoreMatch = text.match(/([\d,]+)/);
        if (scoreMatch) {
          // 移除逗号并转换为数字
          const scoreStr = scoreMatch[1].replace(/,/g, '');
          const scoreNum = parseInt(scoreStr, 10);
          if (!isNaN(scoreNum) && scoreNum >= 0 && scoreNum <= 10000000) {
            score = scoreNum;
            break;
          }
        }
      }
      
      // 备用方法：查找所有span，排除已知的非标题文本
      if (!title) {
        const excludeTexts = ['Potential', 'PTT', 'Title', 'Artist', 'Date Obtained', 
                             'PURE', 'FAR', 'LOST', 'PST', 'PRS', 'FTR', 'BYD', 'ETR',
                             'EX', 'C', 'AA', 'A', 'B', 'D'];
        
        const allSpans = cardElement.querySelectorAll('span');
        for (const span of allSpans) {
          const text = span.textContent.trim();
          if (text && 
              text.length > 3 && 
              text.length < 100 &&
              !text.match(/^[\d.,+\-]+$/) && // 不是纯数字
              !text.match(/^\d{1,2}\/\d{1,2}\/\d{4}/) && // 不是日期
              !excludeTexts.includes(text)) {
            console.log(`[Arcaea Helper] 🎵 备用方法找到标题: "${text}"`);
            title = text;
            break;
          }
        }
      }
      
      return { title, score };
    } catch (error) {
      console.error('[Arcaea Helper] 获取歌曲标题和分数失败:', error);
    }
    return { title: null, score: null };
  }

  /**
   * 在歌曲标题旁边添加定数和单曲PTT显示
   * @param {HTMLElement} titleElement - 标题元素
   * @param {number} constant - 谱面定数
   * @param {number|null} score - 游玩分数
   * @param {HTMLElement} cardElement - 卡片元素，用于添加目标分数
   * @param {number|null} totalPTT - 总PTT值，用于计算目标分数
   */
  function addChartConstantAndPTT(titleElement, constant, score = null, cardElement = null, totalPTT = null) {
    if (!titleElement) return;
    
    // 检查是否已经添加过（通过查找.arcaea-chart-info）
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

      // 定数部分 (灰色) - 根据设置显示
      if (currentSettings.showConstant) {
        const constantSpan = document.createElement('span');
        constantSpan.className = 'arcaea-chart-constant';
        constantSpan.textContent = `(${window.arcaeaData.formatConstant(constant)})`;
        constantSpan.style.color = '#9ca3af';
        constantSpan.style.fontSize = '0.9em';
        
        container.appendChild(constantSpan);
      }

      // 如果有分数，计算并显示单曲PTT - 根据设置显示
      if (currentSettings.showPTT && score !== null && score !== undefined) {
        const playPTT = window.arcaeaData.calculatePlayPTT(score, constant);
        if (playPTT !== null) {
          const pttSpan = document.createElement('span');
          pttSpan.className = 'arcaea-play-ptt';
          pttSpan.textContent = ` ${window.arcaeaData.formatPTT(playPTT)}`;
          pttSpan.style.color = '#667eea';
          pttSpan.style.fontSize = '0.9em';
          pttSpan.style.fontWeight = '700';
          pttSpan.style.marginLeft = '2px';
          
          container.appendChild(pttSpan);
        }
      }

      // 只有在有内容时才添加容器
      if (container.children.length > 0) {
        // 将容器添加到标题元素的父元素中，而不是作为子元素
        // 这样可以避免被 text-overflow: ellipsis 省略
        const parentElement = titleElement.parentElement;
        if (parentElement) {
          // 在标题元素后面插入容器
          if (titleElement.nextSibling) {
            parentElement.insertBefore(container, titleElement.nextSibling);
          } else {
            parentElement.appendChild(container);
          }
        } else {
          // 如果没有父元素，回退到原来的方法
          titleElement.appendChild(container);
        }
      }
      
      // 不在这里添加目标分数，等待第二轮（有总PTT后）再添加
      // 目标分数会在 addTargetScoresToAllCards 中统一添加
      
      processedElements.add(titleElement);
      
      console.log('[Arcaea Helper] 已添加定数和PTT:', constant, score !== null ? `分数: ${score}` : '无分数');
    } catch (error) {
      console.error('[Arcaea Helper] 添加定数显示失败:', error);
    }
  }

  /**
   * 在分数下方添加目标分数显示
   * @param {HTMLElement} cardElement - 卡片元素
   * @param {number} constant - 谱面定数
   * @param {number} currentScore - 当前分数
   * @param {number|null} totalPTT - 总PTT值，用于计算目标单曲PTT
   */
  function addTargetScore(cardElement, constant, currentScore, totalPTT = null) {
    try {
      // 检查整个卡片是否已经添加过目标分数
      if (cardElement.querySelector('.arcaea-target-score')) {
        return;
      }
      
      // 查找分数显示区域 (.ex-main)
      const scoreElements = cardElement.querySelectorAll('.ex-main, [class*="ex-main"]');
      if (scoreElements.length === 0) return;
      
      const scoreElement = scoreElements[0];
      
      // 计算目标分数（传入总PTT）
      const targetScore = window.arcaeaData.calculateTargetScore(constant, currentScore, totalPTT);
      
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
        targetDiv.textContent = `>> ${window.arcaeaData.formatScore(targetScore)}`;
        targetDiv.style.color = '#10b981';
      } else {
        // 满分也无法推分
        targetDiv.textContent = `无法推分`;
        targetDiv.style.color = '#ef4444';
      }
      
      // 将目标分数插入到 experince 容器内部，紧跟在分数元素后面
      const experienceContainer = scoreElement.closest('.experince, [class*="experince"]');
      if (experienceContainer) {
        // 在 experince 容器内部追加目标分数
        experienceContainer.appendChild(targetDiv);
      } else {
        // 备用方案：直接在分数元素的父元素后插入
        const parentElement = scoreElement.parentElement;
        if (parentElement) {
          parentElement.appendChild(targetDiv);
        }
      }
      
      console.log(`[Arcaea Helper] 已添加目标分数: ${targetScore !== null ? targetScore : '无法推分'}`);
    } catch (error) {
      console.error('[Arcaea Helper] 添加目标分数失败:', error);
    }
  }

  /**
   * 添加卡片序号
   */
  function addCardIndex(cardElement, index, isRecent = false) {
    // 检查是否已经添加过序号
    if (cardElement.querySelector('.arcaea-card-index')) {
      return;
    }
    
    // 添加标记以防止重复处理
    if (cardElement.classList.contains('arcaea-indexed')) {
      return;
    }
    cardElement.classList.add('arcaea-indexed');

    try {
      const indexSpan = document.createElement('span');
      indexSpan.className = 'arcaea-card-index';
      indexSpan.textContent = isRecent ? `R${index}` : `#${index}`;
      
      // 为 Recent 10 添加特殊标识以便 CSS 区分
      if (isRecent) {
        indexSpan.setAttribute('data-recent', 'true');
      }
      
      // 将序号添加到卡片的左上角
      cardElement.style.position = 'relative';
      cardElement.insertBefore(indexSpan, cardElement.firstChild);
      
      console.log(`[Arcaea Helper] 已添加序号: ${indexSpan.textContent}`);
    } catch (error) {
      console.error('[Arcaea Helper] 添加序号失败:', error);
    }
  }

  /**
   * 处理单个卡片元素
   * @param {number|null} totalPTT - 总PTT值，用于计算目标分数
   * @returns {number|null} 返回计算的单曲PTT，如果无法计算则返回null
   */
  function processCard(cardElement, index = null, isRecent = false, totalPTT = null) {
    // 检查是否已经处理过（通过class标记）
    if (cardElement.classList.contains('arcaea-processed')) {
      // 如果已处理，尝试返回已计算的PTT值
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
      // 在第一个卡片上打印详细调试信息
      if (debugFirstCard) {
        console.log('[Arcaea Helper] 🔍 === 开始调试第一个卡片 ===');
        console.log('[Arcaea Helper] 卡片HTML预览:', cardElement.outerHTML.substring(0, 300) + '...');
        console.log('[Arcaea Helper] 卡片文本内容:', (cardElement.innerText || '').substring(0, 200));
        debugFirstCard = false;
      }
      
      const { title: songTitle, score } = getSongTitleAndScoreFromCard(cardElement);
      if (!songTitle) {
        return null;
      }

      const difficulty = getDifficultyFromElement(cardElement);
      if (difficulty === null) {
        return null;
      }

      const constant = window.arcaeaData.getChartConstant(songTitle, difficulty, false);
      if (constant === null) {
        return null;
      }

      // 查找标题元素并添加定数和PTT
      const titleElement = Array.from(cardElement.querySelectorAll('span, .title, [class*="title"]'))
        .find(el => el.textContent?.trim() === songTitle);
      
      let playPTT = null;
      if (titleElement) {
        addChartConstantAndPTT(titleElement, constant, score, cardElement, totalPTT);
        console.log(`[Arcaea Helper] ✅ "${songTitle}" [${['PST','PRS','FTR','BYD','ETR'][difficulty]}] 定数:${constant}${score ? ' 分数:'+score : ''}`);
        
        // 计算单曲PTT
        if (score !== null && score !== undefined) {
          playPTT = window.arcaeaData.calculatePlayPTT(score, constant);
        }
      }

      // 如果提供了序号，添加序号显示
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

  /**
   * 在用户名后显示计算的总PTT
   * @param {number} totalPTT - 计算的总PTT值
   */
  function displayTotalPTT(totalPTT) {
    try {
      // 检查是否已经显示过总PTT（全局检查）
      if (document.querySelector('.arcaea-total-ptt')) {
        console.log('[Arcaea Helper] 已存在总PTT显示，跳过');
        return;
      }
      
      // 查找用户名元素
      const usernameElements = document.querySelectorAll('.username, [class*="username"]');
      
      if (usernameElements.length === 0) {
        console.log('[Arcaea Helper] 未找到用户名元素');
        return;
      }

      const usernameElement = usernameElements[0];

      // 创建PTT显示元素
      const pttSpan = document.createElement('span');
      pttSpan.className = 'arcaea-total-ptt';
      pttSpan.textContent = ` (PTT: ${totalPTT.toFixed(4)})`;
      pttSpan.style.color = '#667eea';
      pttSpan.style.fontSize = '0.9em';
      pttSpan.style.fontWeight = '700';
      pttSpan.style.marginLeft = '8px';
      pttSpan.style.whiteSpace = 'nowrap';

      // 将PTT添加到用户名后面
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

      console.log(`[Arcaea Helper] ✅ 已显示总PTT: ${totalPTT.toFixed(4)}`);
    } catch (error) {
      console.error('[Arcaea Helper] 显示总PTT失败:', error);
    }
  }

  /**
   * 创建 PTT +0.01 所需定数的卡片
   * @param {number} currentPTT - 当前PTT值
   * @param {Array} best30PTTs - Best 30 的所有单曲PTT
   * @param {Array} recent10PTTs - Recent 10 的所有单曲PTT
   * @returns {HTMLElement} 返回创建的卡片元素
   */
  function createPTTIncreaseCard(currentPTT, best30PTTs, recent10PTTs) {
    // 步骤1：计算目标实际 PTT
    const displayedPTT = Math.floor(currentPTT * 100) / 100;
    const targetPTT = displayedPTT + 0.01;
    
    // 步骤2：计算总和缺口 ΔS
    const deltaS = 40 * (targetPTT - currentPTT);
    
    // 步骤3：获取 B30 和 R10 的边界值
    const B_min = best30PTTs.length > 0 ? Math.min(...best30PTTs) : 0;
    const R_min = recent10PTTs.length > 0 ? Math.min(...recent10PTTs) : 0;
    
    // 步骤4 & 5：计算所需的新曲最低单曲 PTT
    let x_needed = Infinity;
    
    // 场景A：仅替换 Recent10
    const x_A = R_min + deltaS;
    if (x_A <= B_min) {
      x_needed = Math.min(x_needed, x_A);
    }
    
    // 场景B：仅替换 Best30
    const x_B = B_min + deltaS;
    if (x_B <= R_min) {
      x_needed = Math.min(x_needed, x_B);
    }
    
    // 场景C：同时替换 Best30 和 Recent10
    const x_C = (B_min + R_min + deltaS) / 2;
    if (x_C >= B_min && x_C >= R_min) {
      x_needed = Math.min(x_needed, x_C);
    }
    
    // 如果没有有效场景，使用最保守的估计
    if (x_needed === Infinity) {
      x_needed = Math.max(B_min, R_min) + deltaS;
    }
    
    // 步骤6：计算不同分数等级对应的最低谱面定数
    const scoreGrades = [
      { label: '995W', offset: 1.75 },    // (9950000-9800000)/200000 + 1 = 1.75
      { label: 'EX+', offset: 1.5 },     // (9900000-9800000)/200000 + 1 = 1.5
      { label: 'EX', offset: 1.0 },      // 9800000: +1
      { label: '970W', offset: 0.667 },  // (9700000-9500000)/300000 ≈ 0.667
      { label: '960W', offset: 0.333 },  // (9600000-9500000)/300000 ≈ 0.333
      { label: 'AA', offset: 0.0 }       // 9500000: +0
    ];
    
    const requiredConstants = scoreGrades.map(grade => {
      const rawConstant = x_needed - grade.offset;
      // 向上取整到一位小数
      const constant = Math.ceil(rawConstant * 10) / 10;
      return {
        label: grade.label,
        constant: constant.toFixed(1)
      };
    });

    // 创建卡片容器（模仿原始卡片样式）
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

    // 创建标题
    const title = document.createElement('div');
    title.style.cssText = `
      font-weight: 700;
      font-size: 14px;
      margin-bottom: 4px;
      text-align: center;
      color: #333;
    `;
    title.textContent = `使显示 PTT +0.01 所需最低谱面定数`;

    // 创建副标题
    const subtitle = document.createElement('div');
    subtitle.style.cssText = `
      font-size: 11px;
      margin-bottom: 12px;
      text-align: center;
      color: #555;
    `;
    subtitle.textContent = `当前显示: ${displayedPTT.toFixed(2)} → 目标: ${targetPTT.toFixed(2)}`;
    
    // 创建横向表格
    const table = document.createElement('table');
    table.style.cssText = `
      width: 100%;
      border-collapse: collapse;
      background: rgba(255, 255, 255, 0.95);
      border-radius: 6px;
      overflow: hidden;
      table-layout: fixed;
    `;

    // 创建表头行（分数等级）
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
    
    // 创建数据行（最低定数）
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
    
    // 添加说明文字
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

  /**
   * 在B1歌曲前插入PTT增长卡片
   * @param {number} currentPTT - 当前PTT值
   * @param {Array} best30PTTs - Best 30 的所有单曲PTT
   * @param {Array} recent10PTTs - Recent 10 的所有单曲PTT
   */
  function insertPTTIncreaseCard(currentPTT, best30PTTs, recent10PTTs) {
    try {
      // 检查是否已经插入过
      if (document.querySelector('.arcaea-ptt-increase-card')) {
        console.log('[Arcaea Helper] 已存在PTT增长卡片，跳过');
        return;
      }

      // 查找卡片列表
      const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
      
      if (cardLists.length === 0) {
        console.log('[Arcaea Helper] 未找到卡片列表，无法插入PTT增长卡片');
        return;
      }

      const cardList = cardLists[0];
      
      // 查找第一个卡片（B1）
      const firstCard = cardList.querySelector('[data-v-337fbd7d].card, div[data-v-337fbd7d].card');
      
      if (!firstCard) {
        console.log('[Arcaea Helper] 未找到第一个卡片，无法插入PTT增长卡片');
        return;
      }

      // 创建并插入卡片
      const pttCard = createPTTIncreaseCard(currentPTT, best30PTTs, recent10PTTs);
      cardList.insertBefore(pttCard, firstCard);
      
      console.log('[Arcaea Helper] ✅ 已在B1前插入PTT增长卡片');
    } catch (error) {
      console.error('[Arcaea Helper] 插入PTT增长卡片失败:', error);
    }
  }

  /**
   * 添加 B30 和 R10 之间的分隔线
   */
  function addSectionDivider(cardList) {
    // 检查是否已经添加过分隔线
    if (cardList.querySelector('.arcaea-section-divider')) {
      return;
    }

    try {
      // 直接在 card-list 中查找所有的外层卡片容器
      const cardContainers = cardList.querySelectorAll('[data-v-337fbd7d].card, div[data-v-337fbd7d].card');
      
      console.log(`[Arcaea Helper] 找到 ${cardContainers.length} 个外层卡片容器`);
      
      // 如果容器数量超过 30，在第 30 个后添加分隔元素
      if (cardContainers.length > 30) {
        const divider = document.createElement('div');
        divider.className = 'arcaea-section-divider';
        
        // 在第 31 个容器（R1）之前插入
        const thirtyFirstContainer = cardContainers[30];
        cardList.insertBefore(divider, thirtyFirstContainer);
        console.log('[Arcaea Helper] 已在 card-list 中添加 B30/R10 分隔线');
      }
    } catch (error) {
      console.error('[Arcaea Helper] 添加分隔线失败:', error);
    }
  }

  /**
   * 查找并处理所有曲目卡片
   */
  function processAllCards() {
    try {
      // 查找所有卡片列表容器
      const cardLists = document.querySelectorAll('.card-list, [class*="card-list"]');
      
      console.log(`[Arcaea Helper] 找到 ${cardLists.length} 个卡片列表`);
      
      // 用于追踪实际处理的卡片索引和PTT值
      let totalBest30 = 0;
      let totalRecent10 = 0;
      const best30PTTs = [];
      const recent10PTTs = [];
      
      // 第一轮：处理所有卡片，收集PTT值（不传入totalPTT）
      cardLists.forEach((cardList, listIndex) => {
        // 只查找直接的内层卡片（避免嵌套选择）
        const allElements = cardList.querySelectorAll('[data-v-b3942f14].card, div[data-v-b3942f14].card');
        
        console.log(`[Arcaea Helper] 列表 ${listIndex + 1} 找到 ${allElements.length} 个内层卡片`);
        
        // 在单个列表中处理 Best 30 和 Recent 10
        allElements.forEach((card, cardIndex) => {
          // 前 30 个是 Best 30
          if (cardIndex < 30) {
            const ptt = processCard(card, cardIndex + 1, false, null);
            if (ptt !== null) {
              best30PTTs.push(ptt);
            }
            totalBest30++;
          }
          // 第 31-40 个是 Recent 10
          else if (cardIndex < 40) {
            const recentIndex = cardIndex - 29; // 31->R1, 32->R2, ..., 40->R10
            console.log(`[Arcaea Helper] 处理 Recent 卡片 R${recentIndex}`);
            const ptt = processCard(card, recentIndex, true, null);
            if (ptt !== null) {
              recent10PTTs.push(ptt);
            }
            totalRecent10++;
          }
          // 超过 40 个的不添加序号
          else {
            processCard(card, null, false, null);
          }
        });
        
        // 添加 B30 和 R10 之间的分隔线
        addSectionDivider(cardList);
      });
      
      // 如果没有找到 .card-list，回退到旧的方法
      if (cardLists.length === 0) {
        console.log('[Arcaea Helper] 未找到 card-list，尝试直接查找卡片');
        const allCards = document.querySelectorAll('[data-v-b3942f14].card, div[data-v-b3942f14].card');
        console.log(`[Arcaea Helper] 找到 ${allCards.length} 个内层卡片元素`);
        
        allCards.forEach((card, index) => {
          // 前30个为 Best 30
          if (index < 30) {
            const ptt = processCard(card, index + 1, false, null);
            if (ptt !== null) {
              best30PTTs.push(ptt);
            }
            totalBest30++;
          }
          // 接下来10个为 Recent 10
          else if (index < 40) {
            const recentIndex = index - 29;
            console.log(`[Arcaea Helper] 处理 Recent 卡片 R${recentIndex}`);
            const ptt = processCard(card, recentIndex, true, null);
            if (ptt !== null) {
              recent10PTTs.push(ptt);
            }
            totalRecent10++;
          }
          // 其余卡片不添加序号
          else {
            processCard(card, null, false, null);
          }
        });
      }
      
      console.log(`[Arcaea Helper] 处理完成 - Best 30: ${totalBest30} 个, Recent 10: ${totalRecent10} 个`);
      
      // 计算总PTT
      if (best30PTTs.length > 0 || recent10PTTs.length > 0) {
        const best30Sum = best30PTTs.reduce((sum, ptt) => sum + ptt, 0);
        const recent10Sum = recent10PTTs.reduce((sum, ptt) => sum + ptt, 0);
        const totalPTT = (best30Sum + recent10Sum) / 40;
        
        console.log(`[Arcaea Helper] Best 30 总和: ${best30Sum.toFixed(4)} (${best30PTTs.length}首)`);
        console.log(`[Arcaea Helper] Recent 10 总和: ${recent10Sum.toFixed(4)} (${recent10PTTs.length}首)`);
        console.log(`[Arcaea Helper] 计算的总PTT: ${totalPTT.toFixed(4)}`);
        
        // 显示总PTT
        displayTotalPTT(totalPTT);
        
        // 在B1前插入PTT增长卡片
        insertPTTIncreaseCard(totalPTT, best30PTTs, recent10PTTs);
        
        // 第二轮：重新处理所有卡片，添加基于总PTT的目标分数
        console.log(`[Arcaea Helper] 开始第二轮处理：添加目标分数（基于总PTT=${totalPTT.toFixed(4)}）`);
        addTargetScoresToAllCards(totalPTT);
      } else {
        console.log('[Arcaea Helper] 没有收集到PTT数据，无法计算总PTT');
      }
    } catch (error) {
      console.error('[Arcaea Helper] 处理卡片列表失败:', error);
    }
  }

  /**
   * 为所有卡片添加目标分数（基于总PTT）
   * @param {number} totalPTT - 计算的总PTT值
   */
  function addTargetScoresToAllCards(totalPTT) {
    try {
      // 查找所有内层卡片
      const allCards = document.querySelectorAll('[data-v-b3942f14].card, div[data-v-b3942f14].card');
      
      console.log(`[Arcaea Helper] 为 ${allCards.length} 个卡片添加目标分数`);
      
      allCards.forEach((cardElement) => {
        // 跳过已经有目标分数的卡片
        if (cardElement.querySelector('.arcaea-target-score')) {
          return;
        }
        
        // 获取歌曲信息
        const { title: songTitle, score } = getSongTitleAndScoreFromCard(cardElement);
        if (!songTitle || score === null) return;
        
        const difficulty = getDifficultyFromElement(cardElement);
        if (difficulty === null) return;
        
        const constant = window.arcaeaData.getChartConstant(songTitle, difficulty, false);
        if (constant === null) return;
        
        // 添加目标分数
        if (currentSettings.showTargetScore) {
          addTargetScore(cardElement, constant, score, totalPTT);
        }
      });
      
      console.log(`[Arcaea Helper] ✅ 目标分数添加完成`);
    } catch (error) {
      console.error('[Arcaea Helper] 添加目标分数失败:', error);
    }
  }

  /**
   * 清理旧的状态和观察器
   */
  function cleanup() {
    // 停止旧的 DOM 观察器
    if (domObserver) {
      domObserver.disconnect();
      domObserver = null;
      console.log('[Arcaea Helper] 已停止旧的 DOM 观察器');
    }
    
    // 清空已处理元素集合
    processedElements = new WeakSet();
    
    // 重置调试标志
    debugFirstCard = true;
    
    console.log('[Arcaea Helper] 状态已清理');
  }

  /**
   * 观察DOM变化，处理动态加载的内容
   */
  function observeDOMChanges() {
    // 如果已有观察器，先断开
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
        // 延迟处理，确保DOM完全更新
        setTimeout(processAllCards, 500);
      }
    });

    domObserver.observe(document.body, {
      childList: true,
      subtree: true
    });

    console.log('[Arcaea Helper] DOM观察器已启动');
  }

  /**
   * 初始化或重新初始化扩展
   */
  function init(isReInit = false) {
    console.log(`[Arcaea Helper] ${isReInit ? '重新' : '开始'}初始化`);
    
    // 如果是重新初始化，先清理旧状态
    if (isReInit) {
      cleanup();
    }
    
    // 等待页面加载完成
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

  /**
   * 监听 URL 变化（处理 SPA 路由）
   */
  function observeUrlChanges() {
    // 使用 setInterval 定期检查 URL 变化
    setInterval(() => {
      const newUrl = window.location.href;
      if (newUrl !== currentUrl) {
        console.log('[Arcaea Helper] 🔄 检测到 URL 变化');
        console.log('[Arcaea Helper] 旧 URL:', currentUrl);
        console.log('[Arcaea Helper] 新 URL:', newUrl);
        
        currentUrl = newUrl;
        
        // 检查是否在目标页面
        if (newUrl.includes('/profile/potential')) {
          console.log('[Arcaea Helper] ✅ 进入目标页面，重新初始化...');
          setTimeout(() => init(true), 500);
        } else {
          console.log('[Arcaea Helper] ℹ️ 离开目标页面');
          cleanup();
        }
      }
    }, 1000);
    
    console.log('[Arcaea Helper] URL 变化监听器已启动');
  }

  /**
   * 监听浏览器历史变化（pushState/replaceState）
   */
  function interceptHistoryChanges() {
    const originalPushState = history.pushState;
    const originalReplaceState = history.replaceState;
    
    history.pushState = function() {
      originalPushState.apply(this, arguments);
      console.log('[Arcaea Helper] 🔄 检测到 pushState');
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
      console.log('[Arcaea Helper] 🔄 检测到 replaceState');
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
    
    // 监听 popstate 事件（浏览器前进/后退）
    window.addEventListener('popstate', () => {
      console.log('[Arcaea Helper] 🔄 检测到 popstate');
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
    
    console.log('[Arcaea Helper] History API 拦截器已安装');
  }

  // 启动扩展
  init(false);
  observeUrlChanges();
  interceptHistoryChanges();
})();
