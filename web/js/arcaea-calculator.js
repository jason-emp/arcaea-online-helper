// Arcaea PTT Calculator - Core Algorithm
// 核心算法模块，可在浏览器和 Flutter WebView 中共享

class ArcaeaCalculator {
  /**
   * 计算单曲PTT（Play Potential）
   * @param {number} score - 游玩分数 (0-10000000)
   * @param {number} constant - 谱面定数
   * @returns {number|null} 单曲PTT值，如果计算失败则返回null
   */
  static calculatePlayPTT(score, constant) {
    if (score === null || score === undefined || constant === null || constant === undefined) {
      return null;
    }

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
      if (ptt < 0) {
        ptt = 0;
      }
    }

    return ptt;
  }

  /**
   * 计算显示PTT（向下取整到两位小数）
   * @param {number} ptt - 精确PTT值
   * @returns {number} 显示PTT
   */
  static getDisplayPTT(ptt) {
    if (ptt === null || ptt === undefined) return 0;
    return Math.floor(ptt * 100) / 100;
  }

  /**
   * 计算使总PTT的显示值提升0.01所需的目标分数
   * @param {number} constant - 谱面定数
   * @param {number} currentScore - 当前分数
   * @param {number} totalPTT - 当前总PTT（精确值，40首歌的平均）
   * @returns {number|null} 目标分数，如果已达到最大或无解则返回null
   */
  static calculateTargetScore(constant, currentScore, totalPTT = null) {
    if (constant === null || constant === undefined) return null;
    if (totalPTT === null || totalPTT === undefined) return null;
    
    constant = Number(constant);
    currentScore = Number(currentScore);
    totalPTT = Number(totalPTT);
    
    if (isNaN(constant) || isNaN(currentScore) || isNaN(totalPTT)) return null;
    
    if (currentScore >= 10000000) return null;
    
    const currentDisplayPTT = this.getDisplayPTT(totalPTT);
    const targetDisplayPTT = currentDisplayPTT + 0.01;
    
    const currentPlayPTT = this.calculatePlayPTT(currentScore, constant);
    if (currentPlayPTT === null) return null;
    
    let left = currentScore + 1;
    let right = 10000000;
    let result = null;
    
    while (left <= right) {
      const mid = Math.floor((left + right) / 2);
      const newPlayPTT = this.calculatePlayPTT(mid, constant);
      
      if (newPlayPTT === null) {
        left = mid + 1;
        continue;
      }
      
      const newTotalPTT = totalPTT - currentPlayPTT / 40 + newPlayPTT / 40;
      const newDisplayPTT = this.getDisplayPTT(newTotalPTT);
      
      if (newDisplayPTT >= targetDisplayPTT) {
        result = mid;
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    
    if (result !== null) {
      const newPlayPTT = this.calculatePlayPTT(result, constant);
      const newTotalPTT = totalPTT - currentPlayPTT / 40 + newPlayPTT / 40;
      const newDisplayPTT = this.getDisplayPTT(newTotalPTT);
      
      if (Math.abs(newDisplayPTT - targetDisplayPTT) < 0.0001) {
        return result;
      } else if (newDisplayPTT > targetDisplayPTT + 0.005) {
        return result;
      }
    }
    
    return result;
  }

  /**
   * 计算使显示PTT +0.01所需的最低谱面定数
   * @param {number} currentPTT - 当前精确PTT值
   * @param {Array} best30PTTs - Best 30的所有单曲PTT
   * @param {Array} recent10PTTs - Recent 10的所有单曲PTT
   * @returns {Array} 不同分数等级对应的最低谱面定数
   */
  static calculateRequiredConstants(currentPTT, best30PTTs, recent10PTTs) {
    const displayedPTT = Math.floor(currentPTT * 100) / 100;
    const targetPTT = displayedPTT + 0.01;
    const deltaS = 40 * (targetPTT - currentPTT);
    
    const B_min = best30PTTs.length > 0 ? Math.min(...best30PTTs) : 0;
    const R_min = recent10PTTs.length > 0 ? Math.min(...recent10PTTs) : 0;
    
    let x_needed = Infinity;
    
    // 场景A: 仅替换 Recent10
    const x_A = R_min + deltaS;
    if (x_A <= B_min) {
      x_needed = Math.min(x_needed, x_A);
    }
    
    // 场景B: 仅替换 Best30
    const x_B = B_min + deltaS;
    if (x_B <= R_min) {
      x_needed = Math.min(x_needed, x_B);
    }
    
    // 场景C: 同时替换 Best30 和 Recent10
    const x_C = (B_min + R_min + deltaS) / 2;
    if (x_C >= B_min && x_C >= R_min) {
      x_needed = Math.min(x_needed, x_C);
    }
    
    if (x_needed === Infinity) {
      x_needed = Math.max(B_min, R_min) + deltaS;
    }
    
    const scoreGrades = [
      { label: '995W', offset: 1.75 },
      { label: 'EX+', offset: 1.5 },
      { label: 'EX', offset: 1.0 },
      { label: '970W', offset: 0.667 },
      { label: '960W', offset: 0.333 },
      { label: 'AA', offset: 0.0 }
    ];
    
    return scoreGrades.map(grade => {
      const rawConstant = x_needed - grade.offset;
      const constant = Math.ceil(rawConstant * 10) / 10;
      return {
        label: grade.label,
        constant: constant.toFixed(1)
      };
    });
  }

  /**
   * 格式化定数显示
   */
  static formatConstant(constant) {
    if (constant === null || constant === undefined) return '';
    return constant.toFixed(1);
  }

  /**
   * 格式化PTT显示
   */
  static formatPTT(ptt) {
    if (ptt === null || ptt === undefined) return '';
    return ptt.toFixed(4);
  }

  /**
   * 格式化分数显示（添加千位分隔符）
   */
  static formatScore(score) {
    if (score === null || score === undefined) return '';
    return score.toLocaleString('en-US');
  }
}

// 兼容浏览器和Node.js环境
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ArcaeaCalculator;
} else if (typeof window !== 'undefined') {
  window.ArcaeaCalculator = ArcaeaCalculator;
}
