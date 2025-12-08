// Arcaea Data Loader - 数据加载模块
// 支持浏览器和 Flutter WebView

class ArcaeaDataLoader {
  constructor() {
    this.chartConstants = null;
    this.songList = null;
    this.songIdToTitle = {};
    this.titleToSongId = {};
  }

  /**
   * 初始化数据（从 URL 加载）
   * @param {string} chartConstantUrl - ChartConstant.json 的 URL
   * @param {string} songListUrl - Songlist.json 的 URL
   * @returns {boolean} 是否加载成功
   */
  async init(chartConstantUrl, songListUrl) {
    try {
      console.log('[Arcaea Data] 开始加载数据...');
      
      const chartConstantResponse = await fetch(chartConstantUrl);
      this.chartConstants = await chartConstantResponse.json();
      console.log('[Arcaea Data] ChartConstant 已加载，条目数:', Object.keys(this.chartConstants).length);

      const songListResponse = await fetch(songListUrl);
      this.songList = await songListResponse.json();
      console.log('[Arcaea Data] Songlist 已加载，曲目数:', this.songList?.songs?.length || 0);

      this.buildTitleMapping();
      console.log('[Arcaea Data] ✅ 数据加载成功！');
      return true;
    } catch (error) {
      console.error('[Arcaea Data] ❌ 数据加载失败:', error);
      return false;
    }
  }

  /**
   * 从数据对象初始化（用于直接传入数据）
   * @param {Object} chartConstants - 定数数据对象
   * @param {Object} songList - 歌曲列表对象
   */
  initFromData(chartConstants, songList) {
    this.chartConstants = chartConstants;
    this.songList = songList;
    this.buildTitleMapping();
    console.log('[Arcaea Data] ✅ 数据初始化完成');
  }

  buildTitleMapping() {
    if (!this.songList || !this.songList.songs) return;

    this.songList.songs.forEach(song => {
      const songId = song.id;
      const titleEn = song.title_localized?.en || '';
      const titleJa = song.title_localized?.ja || '';
      
      this.songIdToTitle[songId] = titleEn;
      
      if (titleEn) {
        this.titleToSongId[titleEn.toLowerCase()] = songId;
      }
      if (titleJa) {
        this.titleToSongId[titleJa.toLowerCase()] = songId;
      }
    });
  }

  /**
   * 通过歌曲名称查找定数
   * @param {string} songTitle - 歌曲名
   * @param {number|string} difficulty - 难度 (0-4 或 PST/PRS/FTR/BYD/ETR)
   * @param {boolean} enableLog - 是否启用日志
   * @returns {number|null} 定数值
   */
  getChartConstant(songTitle, difficulty, enableLog = true) {
    try {
      const songId = this.findSongId(songTitle);
      if (!songId) {
        if (enableLog) {
          console.warn('[Arcaea Data] 未找到歌曲:', songTitle);
        }
        return null;
      }

      const constants = this.chartConstants[songId];
      if (!constants) {
        if (enableLog) {
          console.warn('[Arcaea Data] 未找到定数数据:', songId);
        }
        return null;
      }

      const difficultyIndex = this.parseDifficulty(difficulty);
      if (difficultyIndex === -1) {
        console.warn('[Arcaea Data] 无效难度:', difficulty);
        return null;
      }

      const constantData = constants[difficultyIndex];
      if (!constantData || constantData === null) {
        return null;
      }

      return constantData.constant;
    } catch (error) {
      console.error('[Arcaea Data] 获取定数错误:', error);
      return null;
    }
  }

  findSongId(songTitle) {
    if (!songTitle) return null;
    
    const normalizedTitle = songTitle.trim().toLowerCase();
    
    if (this.titleToSongId[normalizedTitle]) {
      return this.titleToSongId[normalizedTitle];
    }
    
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
}

// 兼容浏览器和Node.js环境
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ArcaeaDataLoader;
} else if (typeof window !== 'undefined') {
  window.ArcaeaDataLoader = ArcaeaDataLoader;
}
