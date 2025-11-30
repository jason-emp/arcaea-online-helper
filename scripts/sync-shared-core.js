#!/usr/bin/env node

/**
 * Shared Core 同步工具
 * 自动将 shared_core 的文件同步到各个项目目录
 */

import fs from 'fs-extra';
import path from 'path';
import { fileURLToPath } from 'url';
import chokidar from 'chokidar';
import chalk from 'chalk';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');

// 配置同步规则
const SYNC_CONFIG = {
  // JavaScript 文件同步规则
  js: [
    {
      source: 'shared_core/js/arcaea-calculator.js',
      targets: [
        'chrome_extension/js/arcaea-calculator.js',
        'arcaea_helper_mobile/web/js/arcaea-calculator.js'
      ]
    },
    {
      source: 'shared_core/js/arcaea-data-loader.js',
      targets: [
        'chrome_extension/js/arcaea-data-loader.js',
        'arcaea_helper_mobile/web/js/arcaea-data-loader.js'
      ]
    },
    {
      source: 'shared_core/js/flutter-content.js',
      targets: [
        'arcaea_helper_mobile/web/js/flutter-content.js'
      ]
    }
  ],
  // CSS 文件同步规则
  css: [
    {
      source: 'shared_core/css/arcaea-styles.css',
      targets: [
        'chrome_extension/css/arcaea-styles.css',
        'arcaea_helper_mobile/web/css/arcaea-styles.css'
      ]
    }
  ],
  // 数据文件同步规则
  data: [
    {
      source: 'shared_core/data/ChartConstant.json',
      targets: [
        'chrome_extension/data/ChartConstant.json',
        'arcaea_helper_mobile/assets/data/ChartConstant.json'
      ]
    },
    {
      source: 'shared_core/data/Songlist.json',
      targets: [
        'chrome_extension/data/Songlist.json',
        'arcaea_helper_mobile/assets/data/Songlist.json'
      ]
    }
  ]
};

/**
 * 同步单个文件
 */
async function syncFile(sourceRelPath, targetRelPath, force = false) {
  const sourcePath = path.join(ROOT_DIR, sourceRelPath);
  const targetPath = path.join(ROOT_DIR, targetRelPath);

  try {
    // 检查源文件是否存在
    if (!await fs.pathExists(sourcePath)) {
      console.log(chalk.yellow(`⚠️  源文件不存在: ${sourceRelPath}`));
      return false;
    }

    // 检查目标文件是否需要更新
    if (!force && await fs.pathExists(targetPath)) {
      const sourceStats = await fs.stat(sourcePath);
      const targetStats = await fs.stat(targetPath);
      
      if (sourceStats.mtime <= targetStats.mtime) {
        // 源文件未更新，跳过
        return false;
      }
    }

    // 确保目标目录存在
    await fs.ensureDir(path.dirname(targetPath));

    // 复制文件
    await fs.copy(sourcePath, targetPath, { overwrite: true });
    
    const relTarget = path.relative(ROOT_DIR, targetPath);
    console.log(chalk.green(`✓ 已同步: ${relTarget}`));
    return true;
  } catch (error) {
    console.error(chalk.red(`✗ 同步失败: ${targetRelPath}`));
    console.error(chalk.red(`  错误: ${error.message}`));
    return false;
  }
}

/**
 * 同步所有文件
 */
async function syncAll(force = false) {
  console.log(chalk.cyan('\n🔄 开始同步 shared_core...\n'));
  
  let totalSynced = 0;
  let totalSkipped = 0;

  for (const category of Object.values(SYNC_CONFIG)) {
    for (const rule of category) {
      const { source, targets } = rule;
      
      for (const target of targets) {
        const synced = await syncFile(source, target, force);
        if (synced) {
          totalSynced++;
        } else {
          totalSkipped++;
        }
      }
    }
  }

  console.log(chalk.cyan(`\n✅ 同步完成! 已更新: ${totalSynced} 个文件, 跳过: ${totalSkipped} 个文件\n`));
}

/**
 * 监听文件变化并自动同步
 */
function watchAndSync() {
  console.log(chalk.cyan('\n👀 监听 shared_core 文件变化...\n'));

  // 收集所有需要监听的源文件
  const watchPaths = [];
  for (const category of Object.values(SYNC_CONFIG)) {
    for (const rule of category) {
      watchPaths.push(path.join(ROOT_DIR, rule.source));
    }
  }

  const watcher = chokidar.watch(watchPaths, {
    persistent: true,
    ignoreInitial: false,
    awaitWriteFinish: {
      stabilityThreshold: 300,
      pollInterval: 100
    }
  });

  watcher.on('change', async (changedPath) => {
    const relPath = path.relative(ROOT_DIR, changedPath);
    console.log(chalk.yellow(`\n📝 检测到文件变化: ${relPath}`));

    // 找到对应的同步规则
    for (const category of Object.values(SYNC_CONFIG)) {
      for (const rule of category) {
        if (relPath === rule.source || relPath === rule.source.replace(/\//g, path.sep)) {
          for (const target of rule.targets) {
            await syncFile(rule.source, target, true);
          }
        }
      }
    }
  });

  watcher.on('ready', () => {
    console.log(chalk.green('✅ 监听已启动，等待文件变化...\n'));
    console.log(chalk.gray('按 Ctrl+C 退出监听模式\n'));
  });

  watcher.on('error', (error) => {
    console.error(chalk.red('监听错误:'), error);
  });
}

/**
 * 打印同步配置
 */
function printConfig() {
  console.log(chalk.cyan('\n📋 同步配置:\n'));
  
  for (const [category, rules] of Object.entries(SYNC_CONFIG)) {
    console.log(chalk.bold(`\n${category.toUpperCase()}:`));
    for (const rule of rules) {
      console.log(chalk.gray(`  源: ${rule.source}`));
      for (const target of rule.targets) {
        console.log(chalk.gray(`    → ${target}`));
      }
    }
  }
  console.log('');
}

// 主函数
async function main() {
  const args = process.argv.slice(2);
  const hasWatch = args.includes('--watch') || args.includes('-w');
  const hasForce = args.includes('--force') || args.includes('-f');
  const hasConfig = args.includes('--config') || args.includes('-c');

  if (hasConfig) {
    printConfig();
    return;
  }

  // 首次同步
  await syncAll(hasForce);

  // 如果指定了 --watch，进入监听模式
  if (hasWatch) {
    watchAndSync();
  }
}

main().catch((error) => {
  console.error(chalk.red('错误:'), error);
  process.exit(1);
});
