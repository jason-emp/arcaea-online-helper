#!/usr/bin/env node

/**
 * Arcaea B30/R10 图片生成器
 * 
 * 使用方法：
 * 1. 从Chrome扩展导出JSON数据文件
 * 2. 运行: node scripts/generate-b30r10-image.js <json文件路径>
 * 3. 生成的图片将保存在当前目录
 */

import { createCanvas, loadImage, registerFont } from 'canvas';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import https from 'https';
import http from 'http';
import inquirer from 'inquirer';
import ora from 'ora';
import { glob } from 'glob';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 注册 Fira Sans 字体
let fontLoaded = false;
try {
  registerFont(path.join(__dirname, '../shared_core/data/FiraSans-Regular.ttf'), { family: 'Fira Sans', weight: 'normal' });
  registerFont(path.join(__dirname, '../shared_core/data/FiraSans-Bold.ttf'), { family: 'Fira Sans', weight: 'bold' });
  fontLoaded = true;
} catch (err) {
  // 字体加载失败时将在启动时提示
}

// 配置
const CONFIG = {
  // 画布尺寸
  canvasWidth: 2400,
  canvasHeight: 3900,
  
  // 顶部玩家信息区域
  headerHeight: 280,
  headerPadding: 40,
  
  // 卡片布局 (8行5列)
  rows: 8,
  cols: 5,
  cardWidth: 440,
  cardHeight: 420,
  cardMarginX: 20,
  cardMarginY: 20,
  cardsStartY: 300,
  
  // 颜色方案
  colors: {
    background: '#2d2d3d',
    headerBg: 'rgba(103, 80, 164, 0.15)',
    cardBg: 'rgba(45, 45, 65, 0.95)',
    cardBorder: 'rgba(103, 80, 164, 0.3)',
    primary: '#667eea',
    secondary: '#764ba2',
    textPrimary: '#ffffff',
    textSecondary: '#b8b8d1',
    textTertiary: '#8b8b9e',
    scoreGold: '#ffd700',
    targetScore: '#10b981',
    targetScoreRisky: '#f59e0b', // 橙色警告
    pttBlue: '#60a5fa',
    difficultyColors: {
      PST: '#0A82BE',
      PRS: '#648C3C',
      FTR: '#501948',
      BYD: '#822328',
      ETR: '#5D4E76'
    }
  },
  
  // 字体大小
  fontSize: {
    playerName: 72,
    playerStats: 56,
    playerStatsLabel: 32,
    cardTitle: 48,
    cardScore: 42,
    cardInfo: 36,
    cardDifficulty: 32,
    cardRank: 36,
    cardTarget: 34,
    sectionLabel: 42,
    footer: 24
  }
};

/**
 * 下载图片
 */
async function downloadImage(url) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    
    protocol.get(url, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        // 处理重定向
        downloadImage(res.headers.location).then(resolve).catch(reject);
        return;
      }
      
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        const buffer = Buffer.concat(chunks);
        resolve(buffer);
      });
    }).on('error', reject);
  });
}

/**
 * 根据分数计算评级
 */
function getScoreGrade(score) {
  if (score >= 10000000) return 'PM';
  if (score >= 9900000) return 'EX+';
  if (score >= 9800000) return 'EX';
  if (score >= 9500000) return 'AA';
  if (score >= 9200000) return 'A';
  if (score >= 8900000) return 'B';
  if (score >= 8600000) return 'C';
  return 'D';
}

/**
 * 加载图片（支持URL和本地路径）
 */
async function loadImageSafe(source) {
  try {
    if (source && (source.startsWith('http://') || source.startsWith('https://'))) {
      const buffer = await downloadImage(source);
      return await loadImage(buffer);
    } else if (source) {
      return await loadImage(source);
    }
  } catch (error) {
    // 静默失败
  }
  return null;
}

/**
 * 绘制圆角矩形
 */
function roundRect(ctx, x, y, width, height, radius) {
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + width - radius, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
  ctx.lineTo(x + width, y + height - radius);
  ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
  ctx.lineTo(x + radius, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
  ctx.lineTo(x, y + radius);
  ctx.quadraticCurveTo(x, y, x + radius, y);
  ctx.closePath();
}

/**
 * 绘制渐变文字
 */
function drawGradientText(ctx, text, x, y, gradient) {
  const grad = ctx.createLinearGradient(x, y - 30, x, y + 30);
  grad.addColorStop(0, gradient.start);
  grad.addColorStop(1, gradient.end);
  ctx.fillStyle = grad;
  ctx.fillText(text, x, y);
}

/**
 * 计算单曲PTT
 */
function calculatePlayPTT(score, constant) {
  if (score >= 10000000) {
    return constant + 2;
  } else if (score >= 9800000) {
    return constant + 1 + (score - 9800000) / 200000;
  } else {
    const ptt = constant + (score - 9500000) / 300000;
    return ptt < 0 ? 0 : ptt;
  }
}

/**
 * 计算目标分数（使PTT +0.01）
 */
function calculateTargetScore(constant, currentScore, totalPTT) {
  if (!constant || !currentScore || !totalPTT) return null;
  if (currentScore >= 10000000) return null;
  
  const currentDisplayPTT = Math.floor(totalPTT * 100) / 100;
  const targetDisplayPTT = currentDisplayPTT + 0.01;
  
  // 计算当前单曲PTT
  let currentPlayPTT;
  if (currentScore >= 10000000) {
    currentPlayPTT = constant + 2;
  } else if (currentScore >= 9800000) {
    currentPlayPTT = constant + 1 + (currentScore - 9800000) / 200000;
  } else {
    currentPlayPTT = constant + (currentScore - 9500000) / 300000;
    if (currentPlayPTT < 0) currentPlayPTT = 0;
  }
  
  // 二分搜索目标分数
  let left = currentScore + 1;
  let right = 10000000;
  let result = null;
  
  while (left <= right) {
    const mid = Math.floor((left + right) / 2);
    
    // 计算新的单曲PTT
    let newPlayPTT;
    if (mid >= 10000000) {
      newPlayPTT = constant + 2;
    } else if (mid >= 9800000) {
      newPlayPTT = constant + 1 + (mid - 9800000) / 200000;
    } else {
      newPlayPTT = constant + (mid - 9500000) / 300000;
      if (newPlayPTT < 0) newPlayPTT = 0;
    }
    
    const newTotalPTT = totalPTT - currentPlayPTT / 40 + newPlayPTT / 40;
    const newDisplayPTT = Math.floor(newTotalPTT * 100) / 100;
    
    if (newDisplayPTT >= targetDisplayPTT) {
      result = mid;
      right = mid - 1;
    } else {
      left = mid + 1;
    }
  }
  
  return result;
}

/**
 * 绘制顶部玩家信息
 */
async function drawHeader(ctx, playerData, coverUrl) {
  const { headerHeight, headerPadding, colors, fontSize } = CONFIG;
  
  // 如果有曲绘，使用模糊的曲绘作为背景
  if (coverUrl) {
    const headerBg = await loadImageSafe(coverUrl);
    if (headerBg) {
      ctx.save();
      
      // 创建临时canvas来应用模糊
      const tempCanvas = createCanvas(CONFIG.canvasWidth, headerHeight);
      const tempCtx = tempCanvas.getContext('2d');
      
      // 计算缩放
      const scale = Math.max(
        CONFIG.canvasWidth / headerBg.width,
        headerHeight / headerBg.height
      );
      const scaledWidth = headerBg.width * scale;
      const scaledHeight = headerBg.height * scale;
      const offsetX = (CONFIG.canvasWidth - scaledWidth) / 2;
      const offsetY = (headerHeight - scaledHeight) / 2;
      
      // 绘制到临时canvas
      tempCtx.drawImage(headerBg, offsetX, offsetY, scaledWidth, scaledHeight);
      
      // 应用模糊效果（通过多次缩放实现更强的模糊）
      const blurCanvas = createCanvas(CONFIG.canvasWidth / 8, headerHeight / 8);
      const blurCtx = blurCanvas.getContext('2d');
      blurCtx.drawImage(tempCanvas, 0, 0, blurCanvas.width, blurCanvas.height);
      
      // 绘制模糊后的图片
      ctx.drawImage(blurCanvas, 0, 0, CONFIG.canvasWidth, headerHeight);
      
      // 添加半透明遮罩（加深遮罩）
      ctx.fillStyle = 'rgba(26, 26, 46, 0.75)';
      ctx.fillRect(0, 0, CONFIG.canvasWidth, headerHeight);
      
      ctx.restore();
    }
  } else {
    // 备用：渐变背景
    const gradient = ctx.createLinearGradient(0, 0, CONFIG.canvasWidth, headerHeight);
    gradient.addColorStop(0, 'rgba(103, 80, 164, 0.2)');
    gradient.addColorStop(1, 'rgba(125, 82, 96, 0.2)');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, CONFIG.canvasWidth, headerHeight);
  }
  
  // 玩家名称（居中）
  ctx.font = `bold ${fontSize.playerName}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  ctx.fillStyle = colors.textPrimary;
  ctx.textAlign = 'center';
  ctx.fillText(playerData.username, CONFIG.canvasWidth / 2, 90);
  
  // PTT信息（居中排列）
  const statsY = 170;
  const statsSpacing = 500;
  
  ctx.font = `bold ${fontSize.playerStats}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  
  // 计算总PTT宽度以居中排列
  const centerX = CONFIG.canvasWidth / 2;
  
  // 总PTT
  if (playerData.totalPTT !== null) {
    ctx.fillStyle = colors.scoreGold;
    ctx.textAlign = 'right';
    ctx.fillText(`总PTT: ${playerData.totalPTT.toFixed(4)}`, centerX - statsSpacing / 2 - 50, statsY);
  }
  
  // B30平均
  if (playerData.best30Avg !== null) {
    ctx.fillStyle = colors.textPrimary;
    ctx.textAlign = 'center';
    ctx.fillText(`B30: ${playerData.best30Avg.toFixed(4)}`, centerX, statsY);
  }
  
  // R10平均
  if (playerData.recent10Avg !== null) {
    ctx.fillStyle = colors.textPrimary;
    ctx.textAlign = 'left';
    ctx.fillText(`R10: ${playerData.recent10Avg.toFixed(4)}`, centerX + statsSpacing / 2 + 50, statsY);
  }
  
  // 导出日期（居中）
  ctx.font = `${fontSize.playerStatsLabel}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  ctx.fillStyle = colors.textTertiary;
  ctx.textAlign = 'center';
  const exportDate = new Date(playerData.exportDate);
  ctx.fillText(
    `导出时间: ${exportDate.toLocaleString('zh-CN')}`, 
    CONFIG.canvasWidth / 2, 
    235
  );
}

/**
 * 绘制分区标签 (B30/R10)
 */
function drawSectionLabel(ctx, text, row) {
  const { cardsStartY, cardHeight, cardMarginY, fontSize, colors } = CONFIG;
  
  // 标签位置在该行卡片上方60像素，确保不与上方卡片重叠
  const y = cardsStartY + row * (cardHeight + cardMarginY) - 60;
  
  // 绘制半透明背景
  ctx.save();
  ctx.fillStyle = 'rgba(26, 26, 46, 0.85)';
  const textWidth = ctx.measureText(text).width;
  ctx.fillRect(35, y - fontSize.sectionLabel - 5, textWidth + 200, fontSize.sectionLabel + 15);
  ctx.restore();
  
  ctx.font = `bold ${fontSize.sectionLabel}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  ctx.fillStyle = colors.primary;
  ctx.textAlign = 'left';
  ctx.fillText(text, 40, y);
}

/**
 * 绘制单个歌曲卡片
 */
async function drawCard(ctx, cardData, x, y) {
  const { cardWidth, cardHeight, colors, fontSize } = CONFIG;
  
  // 卡片背景
  ctx.save();
  roundRect(ctx, x, y, cardWidth, cardHeight, 15);
  ctx.fillStyle = colors.cardBg;
  ctx.fill();
  ctx.strokeStyle = colors.cardBorder;
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.clip();
  
  // 如果有曲绘，绘制为背景（带透明度）
  if (cardData.coverUrl) {
    const coverImage = await loadImageSafe(cardData.coverUrl);
    if (coverImage) {
      ctx.globalAlpha = 0.15;
      ctx.drawImage(coverImage, x, y, cardWidth, cardHeight);
      ctx.globalAlpha = 1.0;
    }
  }
  
  ctx.restore();
  
  // 排名标签
  ctx.font = `bold ${fontSize.cardRank}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  ctx.fillStyle = cardData.rank <= 30 ? colors.scoreGold : colors.secondary;
  ctx.textAlign = 'left';
  const rankText = cardData.rank <= 30 ? `#${cardData.rank}` : `R${cardData.rank}`;
  ctx.fillText(rankText, x + 15, y + 45);
  
  // 难度标签（带彩色圆角矩形背景）
  const diffColor = colors.difficultyColors[cardData.difficulty] || colors.primary;
  ctx.font = `bold ${fontSize.cardDifficulty}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  ctx.textAlign = 'right';
  
  const diffText = cardData.difficulty;
  const diffTextWidth = ctx.measureText(diffText).width;
  const diffPadding = 10;
  const diffX = x + cardWidth - 15;
  const diffY = y + 45;
  const diffRadius = 6;
  
  // 绘制难度圆角矩形背景
  ctx.save();
  roundRect(
    ctx,
    diffX - diffTextWidth - diffPadding,
    diffY - fontSize.cardDifficulty - 4,
    diffTextWidth + diffPadding * 2,
    fontSize.cardDifficulty + 8,
    diffRadius
  );
  ctx.fillStyle = diffColor;
  ctx.fill();
  ctx.restore();
  
  // 绘制难度文字（白色）
  ctx.fillStyle = '#ffffff';
  ctx.fillText(diffText, diffX, diffY);
  
  // 歌曲名称（自动换行）
  ctx.font = `bold ${fontSize.cardTitle}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  ctx.fillStyle = colors.textPrimary;
  ctx.textAlign = 'left';
  
  const maxTitleWidth = cardWidth - 30;
  const words = cardData.songTitle.split(' ');
  let line = '';
  let lineY = y + 90;
  const lineHeight = fontSize.cardTitle + 5;
  let lines = [];
  
  for (let word of words) {
    const testLine = line + (line ? ' ' : '') + word;
    const testWidth = ctx.measureText(testLine).width;
    
    if (testWidth > maxTitleWidth && line) {
      lines.push(line);
      line = word;
    } else {
      line = testLine;
    }
  }
  if (line) lines.push(line);
  
  // 最多显示2行
  if (lines.length > 2) {
    lines = lines.slice(0, 2);
    lines[1] = lines[1].slice(0, -3) + '...';
  }
  
  lines.forEach((line, i) => {
    ctx.fillText(line, x + 15, lineY + i * lineHeight);
  });
  
  const titleEndY = lineY + (lines.length - 1) * lineHeight;
  
  // 分数
  ctx.font = `bold ${fontSize.cardScore}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  ctx.fillStyle = colors.scoreGold;
  const scoreText = cardData.score ? cardData.score.toLocaleString('en-US') : 'N/A';
  ctx.fillText(scoreText, x + 15, titleEndY + 55);
  
  // 评级（在分数右侧）
  if (cardData.score) {
    const grade = getScoreGrade(cardData.score);
    ctx.font = `bold ${fontSize.cardInfo}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
    ctx.fillStyle = '#ffffff';
    const scoreWidth = ctx.measureText(scoreText).width;
    ctx.fillText(grade, x + 15 + scoreWidth + 25, titleEndY + 55);
  }
  
  // 定数和PTT信息
  const infoY = titleEndY + 100;
  
  // 定数
  if (cardData.constant !== null) {
    ctx.font = `${fontSize.cardInfo}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
    ctx.fillStyle = colors.textSecondary;
    ctx.fillText(`定数: ${cardData.constant.toFixed(1)}`, x + 15, infoY);
  }
  
  // PTT（浅蓝色加粗）
  if (cardData.playPTT !== null) {
    ctx.font = `bold ${fontSize.cardInfo}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
    ctx.fillStyle = colors.pttBlue;
    ctx.textAlign = 'right';
    ctx.fillText(`PTT: ${cardData.playPTT.toFixed(4)}`, x + cardWidth - 15, infoY);
  }
  
  // 重置对齐
  ctx.textAlign = 'left';
}

/**
 * 绘制单个歌曲卡片（带目标分数）
 */
async function drawCardWithTarget(ctx, cardData, x, y, totalPTT, isRecent = false, best30List = [], recent10List = []) {
  const { cardWidth, cardHeight, colors, fontSize } = CONFIG;
  
  // 卡片背景
  ctx.save();
  roundRect(ctx, x, y, cardWidth, cardHeight, 15);
  ctx.fillStyle = colors.cardBg;
  ctx.fill();
  ctx.strokeStyle = colors.cardBorder;
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.clip();
  
  // 如果有曲绘，绘制为背景（带透明度）
  if (cardData.coverUrl) {
    const coverImage = await loadImageSafe(cardData.coverUrl);
    if (coverImage) {
      ctx.globalAlpha = 0.15;
      ctx.drawImage(coverImage, x, y, cardWidth, cardHeight);
      ctx.globalAlpha = 1.0;
    }
  }
  
  ctx.restore();
  
  // 排名标签
  ctx.font = `bold ${fontSize.cardRank}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  // B30使用金色，R10使用绿色
  ctx.fillStyle = isRecent ? colors.targetScore : colors.scoreGold;
  ctx.textAlign = 'left';
  const rankText = isRecent ? `R${cardData.rank}` : `#${cardData.rank}`;
  ctx.fillText(rankText, x + 15, y + 50);
  
  // 难度标签（带彩色圆角矩形背景）
  const diffColor = colors.difficultyColors[cardData.difficulty] || colors.primary;
  ctx.font = `bold ${fontSize.cardDifficulty}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  ctx.textAlign = 'right';
  
  const diffText = cardData.difficulty;
  const diffTextWidth = ctx.measureText(diffText).width;
  const diffPadding = 10;
  const diffX = x + cardWidth - 15;
  const diffY = y + 50;
  const diffRadius = 6;
  
  // 绘制难度圆角矩形背景
  ctx.save();
  roundRect(
    ctx,
    diffX - diffTextWidth - diffPadding,
    diffY - fontSize.cardDifficulty - 4,
    diffTextWidth + diffPadding * 2,
    fontSize.cardDifficulty + 8,
    diffRadius
  );
  ctx.fillStyle = diffColor;
  ctx.fill();
  ctx.restore();
  
  // 绘制难度文字（白色）
  ctx.fillStyle = '#ffffff';
  ctx.fillText(diffText, diffX, diffY);
  
  // 歌曲名称（自动换行）
  ctx.font = `bold ${fontSize.cardTitle}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  ctx.fillStyle = colors.textPrimary;
  ctx.textAlign = 'left';
  
  const maxTitleWidth = cardWidth - 30;
  const words = cardData.songTitle.split(' ');
  let line = '';
  let lineY = y + 100;
  const lineHeight = fontSize.cardTitle + 5;
  let lines = [];
  
  for (let word of words) {
    const testLine = line + (line ? ' ' : '') + word;
    const testWidth = ctx.measureText(testLine).width;
    
    if (testWidth > maxTitleWidth && line) {
      lines.push(line);
      line = word;
    } else {
      line = testLine;
    }
  }
  if (line) lines.push(line);
  
  // 最多显示2行
  if (lines.length > 2) {
    lines = lines.slice(0, 2);
    lines[1] = lines[1].slice(0, -3) + '...';
  }
  
  lines.forEach((line, i) => {
    ctx.fillText(line, x + 15, lineY + i * lineHeight);
  });
  
  const titleEndY = lineY + (lines.length - 1) * lineHeight;
  
  // 分数
  ctx.font = `bold ${fontSize.cardScore}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  ctx.fillStyle = colors.scoreGold;
  const scoreText = cardData.score ? cardData.score.toLocaleString('en-US') : 'N/A';
  ctx.fillText(scoreText, x + 15, titleEndY + 60);
  
  // 评级（在分数右侧）
  if (cardData.score) {
    const grade = getScoreGrade(cardData.score);
    ctx.font = `bold ${fontSize.cardInfo}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
    ctx.fillStyle = '#ffffff';
    const scoreWidth = ctx.measureText(scoreText).width;
    ctx.fillText(grade, x + 15 + scoreWidth + 35, titleEndY + 60);
  }
  
  // 定数和PTT信息
  const infoY = titleEndY + 110;
  
  // 定数
  if (cardData.constant !== null) {
    ctx.font = `${fontSize.cardInfo}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
    ctx.fillStyle = colors.textSecondary;
    ctx.fillText(`定数: ${cardData.constant.toFixed(1)}`, x + 15, infoY);
  }
  
  // PTT（浅蓝色加粗）
  if (cardData.playPTT !== null) {
    ctx.font = `bold ${fontSize.cardInfo}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
    ctx.fillStyle = colors.pttBlue;
    ctx.textAlign = 'right';
    ctx.fillText(`PTT: ${cardData.playPTT.toFixed(4)}`, x + cardWidth - 15, infoY);
  }
  
  // 目标分数
  const targetScore = calculateTargetScore(cardData.constant, cardData.score, totalPTT);
  
  if (targetScore !== null) {
    ctx.font = `bold ${fontSize.cardTarget}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
    ctx.fillStyle = colors.targetScore;
    ctx.textAlign = 'left';
    ctx.fillText(`>> ${targetScore.toLocaleString('en-US')}`, x + 15, infoY + 45);
  }
  
  // 重置对齐
  ctx.textAlign = 'left';
}

/**
 * 主函数：生成图片
 */
async function generateImage(jsonData, spinner) {
  const canvas = createCanvas(CONFIG.canvasWidth, CONFIG.canvasHeight);
  const ctx = canvas.getContext('2d');
  
  // 绘制背景色
  if (spinner) spinner.text = '正在绘制背景...';
  ctx.fillStyle = CONFIG.colors.background;
  ctx.fillRect(0, 0, CONFIG.canvasWidth, CONFIG.canvasHeight);
  
  // 随机选择一个曲绘作为背景
  const allSongs = [...jsonData.best30, ...jsonData.recent10];
  const randomSong = allSongs[Math.floor(Math.random() * allSongs.length)];
  
  if (randomSong && randomSong.coverUrl) {
    const bgImage = await loadImageSafe(randomSong.coverUrl);
    if (bgImage) {
      // 计算缩放比例以覆盖整个画布
      const scale = Math.max(
        CONFIG.canvasWidth / bgImage.width,
        CONFIG.canvasHeight / bgImage.height
      );
      const scaledWidth = bgImage.width * scale;
      const scaledHeight = bgImage.height * scale;
      const offsetX = (CONFIG.canvasWidth - scaledWidth) / 2;
      const offsetY = (CONFIG.canvasHeight - scaledHeight) / 2;
      
      // 绘制曲绘
      ctx.drawImage(bgImage, offsetX, offsetY, scaledWidth, scaledHeight);
      
      // 添加深色遮罩
      ctx.fillStyle = 'rgba(20, 20, 30, 0.85)';
      ctx.fillRect(0, 0, CONFIG.canvasWidth, CONFIG.canvasHeight);
    }
  }
  
  // 绘制顶部玩家信息
  if (spinner) spinner.text = '正在绘制玩家信息...';
  await drawHeader(ctx, jsonData.player, randomSong?.coverUrl);
  
  // 计算卡片位置并绘制
  const { cols, cardWidth, cardHeight, cardMarginX, cardMarginY, cardsStartY } = CONFIG;
  const totalWidth = cols * cardWidth + (cols - 1) * cardMarginX;
  const startX = (CONFIG.canvasWidth - totalWidth) / 2;
  
  const totalPTT = jsonData.player.totalPTT;
  const totalCards = jsonData.best30.length + jsonData.recent10.length;
  let processedCards = 0;
  
  // 先绘制 Best 30（从位置0开始）
  for (let i = 0; i < jsonData.best30.length; i++) {
    const row = Math.floor(i / cols);
    const col = i % cols;
    
    const x = startX + col * (cardWidth + cardMarginX);
    const y = cardsStartY + row * (cardHeight + cardMarginY);
    
    processedCards++;
    if (spinner) {
      spinner.text = `正在绘制卡片... (${processedCards}/${totalCards}) - B${i + 1}`;
    }
    
    await drawCardWithTarget(ctx, jsonData.best30[i], x, y, totalPTT, false, jsonData.best30, jsonData.recent10);
  }
  
  // 再绘制 Recent 10（从位置30开始，即使Best 30不满30张）
  for (let i = 0; i < jsonData.recent10.length; i++) {
    const cardIndex = 30 + i; // 从第31张卡片开始
    const row = Math.floor(cardIndex / cols);
    const col = cardIndex % cols;
    
    const x = startX + col * (cardWidth + cardMarginX);
    const y = cardsStartY + row * (cardHeight + cardMarginY);
    
    processedCards++;
    if (spinner) {
      spinner.text = `正在绘制卡片... (${processedCards}/${totalCards}) - R${i + 1}`;
    }
    
    await drawCardWithTarget(ctx, jsonData.recent10[i], x, y, totalPTT, true, jsonData.best30, jsonData.recent10);
  }
  
  // 绘制底部文字
  if (spinner) spinner.text = '正在添加底部信息...';
  ctx.font = `${CONFIG.fontSize.footer}px "Fira Sans", "Microsoft YaHei", "PingFang SC", sans-serif`;
  ctx.fillStyle = CONFIG.colors.textTertiary;
  ctx.textAlign = 'center';
  ctx.fillText(
    'Generated by Arcaea Online Helper',
    CONFIG.canvasWidth / 2,
    CONFIG.canvasHeight - 30
  );
  
  return canvas;
}

/**
 * 搜索JSON文件
 */
async function findJsonFiles() {
  const patterns = [
    'arcaea-b30r10-*.json',
    '*.json'
  ];
  
  const files = new Set();
  
  for (const pattern of patterns) {
    try {
      const matches = await glob(pattern, { 
        cwd: process.cwd(),
        absolute: false,
        ignore: ['node_modules/**', 'package*.json', 'project-info.json']
      });
      matches.forEach(file => files.add(file));
    } catch (error) {
      // 忽略错误
    }
  }
  
  // 按修改时间排序（最新的在前）
  const filesArray = Array.from(files);
  const filesWithStats = await Promise.all(
    filesArray.map(async (file) => {
      try {
        const stats = await fs.stat(file);
        return { file, mtime: stats.mtime };
      } catch {
        return null;
      }
    })
  );
  
  return filesWithStats
    .filter(item => item !== null)
    .sort((a, b) => b.mtime - a.mtime)
    .map(item => item.file);
}

/**
 * 验证JSON文件
 */
async function validateJsonFile(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf-8');
    const data = JSON.parse(content);
    
    if (!data.player || !data.best30 || !data.recent10) {
      return { valid: false, error: 'JSON数据格式不正确，缺少必要字段' };
    }
    
    if (!data.player.username) {
      return { valid: false, error: '缺少玩家用户名' };
    }
    
    return { valid: true, data };
  } catch (error) {
    return { valid: false, error: error.message };
  }
}

/**
 * 选择JSON文件
 */
async function selectJsonFile() {
  const args = process.argv.slice(2);
  
  // 如果提供了命令行参数，直接使用
  if (args.length > 0) {
    const filePath = args[0];
    const validation = await validateJsonFile(filePath);
    
    if (!validation.valid) {
      console.error(`\n❌ 文件验证失败: ${validation.error}\n`);
      throw new Error('JSON文件无效');
    }
    
    return { filePath, data: validation.data };
  }
  
  // 自动搜索JSON文件
  console.log('🔍 正在搜索JSON文件...\n');
  const jsonFiles = await findJsonFiles();
  
  if (jsonFiles.length === 0) {
    console.error('❌ 未找到任何JSON文件');
    console.log('\n请确保：');
    console.log('  1. JSON文件在当前目录');
    console.log('  2. 文件名包含 "arcaea-b30r10" 或以 .json 结尾');
    console.log('\n或者手动指定文件路径：');
    console.log('  npm run generate-image <文件路径>');
    console.log('  node scripts/generate-b30r10-image.js <文件路径>\n');
    process.exit(1);
  }
  
  // 验证所有找到的JSON文件
  const validFiles = [];
  for (const file of jsonFiles) {
    const validation = await validateJsonFile(file);
    if (validation.valid) {
      validFiles.push({ file, data: validation.data });
    }
  }
  
  if (validFiles.length === 0) {
    console.error('❌ 未找到有效的Arcaea数据JSON文件\n');
    process.exit(1);
  }
  
  // 如果只有一个有效文件，直接使用
  if (validFiles.length === 1) {
    console.log(`✅ 自动选择: ${validFiles[0].file}\n`);
    return { filePath: validFiles[0].file, data: validFiles[0].data };
  }
  
  // 多个文件时让用户选择
  const choices = validFiles.map(({ file, data }) => ({
    name: `${file} (玩家: ${data.player.username}, PTT: ${data.player.totalPTT?.toFixed(2) || 'N/A'})`,
    value: file,
    short: file
  }));
  
  const { selectedFile } = await inquirer.prompt([
    {
      type: 'list',
      name: 'selectedFile',
      message: '选择要生成图片的JSON文件:',
      choices,
      pageSize: 10
    }
  ]);
  
  const selected = validFiles.find(f => f.file === selectedFile);
  return { filePath: selectedFile, data: selected.data };
}

/**
 * 主程序入口
 */
async function main() {
  try {
    console.log('\n╔══════════════════════════════════════════╗');
    console.log('║   Arcaea B30/R10 图片生成器             ║');
    console.log('╚══════════════════════════════════════════╝\n');
    
    if (!fontLoaded) {
      console.log('⚠️  提示: Fira Sans 字体未加载，将使用系统默认字体\n');
    }
    
    // 选择JSON文件
    const { filePath, data: jsonData } = await selectJsonFile();
    
    console.log('📋 数据概览:');
    console.log(`  👤 玩家: ${jsonData.player.username}`);
    console.log(`  📈 总PTT: ${jsonData.player.totalPTT?.toFixed(4) || 'N/A'}`);
    console.log(`  🎵 Best 30: ${jsonData.best30.length} 首`);
    console.log(`  🎵 Recent 10: ${jsonData.recent10.length} 首\n`);
    
    // 确认生成
    const { confirm } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'confirm',
        message: '开始生成图片？',
        default: true
      }
    ]);
    
    if (!confirm) {
      console.log('\n❌ 已取消\n');
      process.exit(0);
    }
    
    console.log('');
    
    // 生成图片（带进度提示）
    const spinner = ora('正在生成图片...').start();
    
    try {
      const canvas = await generateImage(jsonData, spinner);
      spinner.text = '正在保存图片...';
      
      // 保存图片
      const outputFileName = `arcaea-b30r10-${jsonData.player.username}-${Date.now()}.png`;
      const outputPath = path.join(process.cwd(), outputFileName);
      
      const buffer = canvas.toBuffer('image/png');
      await fs.writeFile(outputPath, buffer);
      
      spinner.succeed('图片生成成功！');
      
      console.log('\n📊 输出信息:');
      console.log(`  📁 文件: ${outputFileName}`);
      console.log(`  📏 尺寸: ${CONFIG.canvasWidth}x${CONFIG.canvasHeight}`);
      console.log(`  📦 大小: ${(buffer.length / 1024 / 1024).toFixed(2)} MB`);
      console.log(`  💾 路径: ${outputPath}\n`);
      
    } catch (error) {
      spinner.fail('图片生成失败');
      throw error;
    }
    
  } catch (error) {
    console.error('\n❌ 错误:', error.message);
    if (process.env.DEBUG) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

// 运行主程序
main();
