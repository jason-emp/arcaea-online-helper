// Arcaea Chart Constant Data Module

class ArcaeaData {
  constructor() {
    this.chartConstants = null;
    this.songList = null;
    this.songIdToTitle = {};
    this.titleToSongId = {};
  }

  async init() {
    try {
      console.log('[Arcaea Helper] 开始加载数据...');
      
      // 加载 Chart Constant 数据
      const chartConstantUrl = chrome.runtime.getURL('ChartConstant.json');
      console.log('[Arcaea Helper] ChartConstant URL:', chartConstantUrl);
      
      const chartConstantResponse = await fetch(chartConstantUrl);
      console.log('[Arcaea Helper] ChartConstant 响应状态:', chartConstantResponse.status);
      
      this.chartConstants = await chartConstantResponse.json();
      console.log('[Arcaea Helper] ChartConstant 数据已解析，条目数:', Object.keys(this.chartConstants).length);

      // 加载 Song List 数据
      const songListUrl = chrome.runtime.getURL('Songlist.json');
      console.log('[Arcaea Helper] Songlist URL:', songListUrl);
      
      const songListResponse = await fetch(songListUrl);
      console.log('[Arcaea Helper] Songlist 响应状态:', songListResponse.status);
      
      this.songList = await songListResponse.json();
      console.log('[Arcaea Helper] Songlist 数据已解析，曲目数:', this.songList?.songs?.length || 0);

      // 构建歌曲标题映射
      this.buildTitleMapping();
      console.log('[Arcaea Helper] 标题映射已构建，映射数量:', Object.keys(this.titleToSongId).length);
      
      console.log('[Arcaea Helper] ✅ 数据加载成功！');
      console.log('[Arcaea Helper] 可以使用: window.arcaeaData.getChartConstant("曲目名", 难度)');
      return true;
    } catch (error) {
      console.error('[Arcaea Helper] ❌ 数据加载失败:', error);
      console.error('[Arcaea Helper] 错误详情:', error.message);
      console.error('[Arcaea Helper] 错误堆栈:', error.stack);
      return false;
    }
  }

  buildTitleMapping() {
    if (!this.songList || !this.songList.songs) return;

    this.songList.songs.forEach(song => {
      const songId = song.id;
      const titleEn = song.title_localized?.en || '';
      const titleJa = song.title_localized?.ja || '';
      
      // 存储 ID -> 标题映射
      this.songIdToTitle[songId] = titleEn;
      
      // 存储 标题 -> ID 映射 (支持英文和日文)
      if (titleEn) {
        this.titleToSongId[titleEn.toLowerCase()] = songId;
      }
      if (titleJa) {
        this.titleToSongId[titleJa.toLowerCase()] = songId;
      }
    });
  }

  // 通过歌曲名称查找定数
  getChartConstant(songTitle, difficulty, enableLog = true) {
    try {
      // 查找歌曲 ID
    const songId = this.findSongId(songTitle);
    if (!songId) {
      if (enableLog) {
        console.warn('[Arcaea Helper] 未找到歌曲:', songTitle);
      }
      return null;
    }      // 获取定数数据
      const constants = this.chartConstants[songId];
      if (!constants) {
        if (enableLog) {
          console.warn('[Arcaea Helper] 未找到定数数据:', songId);
        }
        return null;
      }

      // 难度映射: 0=Past, 1=Present, 2=Future, 3=Beyond, 4=Eternal
      const difficultyIndex = this.parseDifficulty(difficulty);
      if (difficultyIndex === -1) {
        console.warn('[Arcaea Helper] 无效难度:', difficulty);
        return null;
      }

      const constantData = constants[difficultyIndex];
      if (!constantData || constantData === null) {
        return null;
      }

      return constantData.constant;
    } catch (error) {
      console.error('[Arcaea Helper] 获取定数错误:', error);
      return null;
    }
  }

  findSongId(songTitle) {
    if (!songTitle) return null;
    
    const normalizedTitle = songTitle.trim().toLowerCase();
    
    // 直接匹配
    if (this.titleToSongId[normalizedTitle]) {
      return this.titleToSongId[normalizedTitle];
    }
    
    // 模糊匹配 - 尝试去除特殊字符
    const simplifiedTitle = normalizedTitle
      .replace(/[^\w\s\u3040-\u309f\u30a0-\u30ff\u4e00-\u9faf]/g, '')
      .replace(/\s+/g, '');
    
    for (const [title, songId] of Object.entries(this.titleToSongId)) {
      const simplifiedKey = title
        .replace(/[^\w\s\u3040-\u309f\u30a0-\u30ff\u4e00-\u9faf]/g, '')
        .replace(/\s+/g, '');
      
      if (simplifiedKey === simplifiedTitle) {
        return songId;
      }
    }
    
    return null;
  }

  parseDifficulty(difficulty) {
    if (typeof difficulty === 'number') return difficulty;
    
    const diffMap = {
      'past': 0,
      'pst': 0,
      'present': 1,
      'prs': 1,
      'future': 2,
      'ftr': 2,
      'beyond': 3,
      'byd': 3,
      'eternal': 4,
      'etr': 4
    };
    
    const normalized = String(difficulty).toLowerCase().trim();
    return diffMap[normalized] ?? -1;
  }

  // 格式化定数显示
  formatConstant(constant) {
    if (constant === null || constant === undefined) return '';
    return constant.toFixed(1);
  }

  /**
   * 计算单曲PTT（Play Potential）
   * @param {number} score - 游玩分数 (0-10000000)
   * @param {number} constant - 谱面定数
   * @returns {number|null} 单曲PTT值，如果计算失败则返回null
   */
  calculatePlayPTT(score, constant) {
    if (score === null || score === undefined || constant === null || constant === undefined) {
      return null;
    }

    // 确保分数和定数是数字
    score = Number(score);
    constant = Number(constant);

    if (isNaN(score) || isNaN(constant)) {
      return null;
    }

    let ptt;

    if (score >= 10000000) {
      // PM: 定数+2
      ptt = constant + 2;
    } else if (score >= 9800000) {
      // 9,800,000 到 10,000,000: 定数+1+(分数-9,800,000)/200,000
      ptt = constant + 1 + (score - 9800000) / 200000;
    } else {
      // 低于 9,800,000: 定数+(分数-9,500,000)/300,000
      ptt = constant + (score - 9500000) / 300000;
      // PTT下限为0
      if (ptt < 0) {
        ptt = 0;
      }
    }

    return ptt;
  }

  // 格式化PTT显示
  formatPTT(ptt) {
    if (ptt === null || ptt === undefined) return '';
    return ptt.toFixed(4);
  }

  /**
   * 计算显示PTT（向下取整到两位小数）
   * @param {number} ptt - 精确PTT值
   * @returns {number} 显示PTT
   */
  getDisplayPTT(ptt) {
    if (ptt === null || ptt === undefined) return 0;
    return Math.floor(ptt * 100) / 100;
  }

  /**
   * 计算使总PTT的显示值提升0.01所需的目标分数
   * 使用二分搜索找到最小的分数S，使得新的显示总PTT >= 旧的显示总PTT + 0.01
   * @param {number} constant - 谱面定数
   * @param {number} currentScore - 当前分数
   * @param {number} totalPTT - 当前总PTT（精确值，40首歌的平均）
   * @returns {number|null} 目标分数，如果已达到最大或无解则返回null
   */
  calculateTargetScore(constant, currentScore, totalPTT = null) {
    if (constant === null || constant === undefined) return null;
    if (totalPTT === null || totalPTT === undefined) return null;
    
    constant = Number(constant);
    currentScore = Number(currentScore);
    totalPTT = Number(totalPTT);
    
    if (isNaN(constant) || isNaN(currentScore) || isNaN(totalPTT)) return null;
    
    // 如果已经是PM（10,000,000），无法再提高
    if (currentScore >= 10000000) return null;
    
    // 使用二分搜索找到最小的目标分数
    const currentDisplayPTT = this.getDisplayPTT(totalPTT);
    const targetDisplayPTT = currentDisplayPTT + 0.01;
    
    // 计算当前单曲PTT
    const currentPlayPTT = this.calculatePlayPTT(currentScore, constant);
    if (currentPlayPTT === null) return null;
    
    // 二分搜索范围：[currentScore + 1, 10000000]
    let left = currentScore + 1;
    let right = 10000000;
    let result = null;
    
    while (left <= right) {
      const mid = Math.floor((left + right) / 2);
      
      // 计算新的单曲PTT
      const newPlayPTT = this.calculatePlayPTT(mid, constant);
      if (newPlayPTT === null) {
        left = mid + 1;
        continue;
      }
      
      // 计算新的总PTT（替换当前这首歌的PTT）
      // 新总PTT = 旧总PTT - 旧单曲PTT/40 + 新单曲PTT/40
      const newTotalPTT = totalPTT - currentPlayPTT / 40 + newPlayPTT / 40;
      const newDisplayPTT = this.getDisplayPTT(newTotalPTT);
      
      if (newDisplayPTT >= targetDisplayPTT) {
        // 找到一个可行解，尝试找更小的
        result = mid;
        right = mid - 1;
      } else {
        // 分数不够，需要更高的分数
        left = mid + 1;
      }
    }
    
    // 检查找到的解是否有效
    if (result !== null) {
      // 验证这个分数是否会让显示PTT刚好 +0.01，而不是跳到 +0.02 或更高
      const newPlayPTT = this.calculatePlayPTT(result, constant);
      const newTotalPTT = totalPTT - currentPlayPTT / 40 + newPlayPTT / 40;
      const newDisplayPTT = this.getDisplayPTT(newTotalPTT);
      
      // 允许一些浮点误差（0.0001）
      if (Math.abs(newDisplayPTT - targetDisplayPTT) < 0.0001) {
        return result;
      } else if (newDisplayPTT > targetDisplayPTT + 0.005) {
        // 如果直接跳到了 +0.02 或更高，说明无法刚好 +0.01
        // 这种情况下，返回这个分数（虽然会跳过 +0.01）
        return result;
      }
    }
    
    return result;
  }

  // 格式化分数显示（添加千位分隔符）
  formatScore(score) {
    if (score === null || score === undefined) return '';
    return score.toLocaleString('en-US');
  }
}

// 创建全局实例
if (typeof window !== 'undefined') {
  console.log('[Arcaea Helper] 📦 正在创建 ArcaeaData 实例...');
  window.arcaeaData = new ArcaeaData();
  console.log('[Arcaea Helper] ✅ ArcaeaData 实例已创建');
  console.log('[Arcaea Helper] 对象类型:', typeof window.arcaeaData);
  console.log('[Arcaea Helper] 可用方法:', Object.getOwnPropertyNames(Object.getPrototypeOf(window.arcaeaData)));
} else {
  console.error('[Arcaea Helper] ❌ window 对象不可用');
}
