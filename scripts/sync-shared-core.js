#!/usr/bin/env node

/**
 * Shared Core 同步工具
 * 自动将 shared_core 的文件同步到各个项目目录
 * 
 * 功能：
 * - 基于内容哈希的智能同步（只在内容真正变化时同步）
 * - 反向检测（警告误修改同步文件的情况）
 * - 同步日志记录
 * - 自动备份
 */

import fs from 'fs-extra';
import path from 'path';
import { fileURLToPath } from 'url';
import { createHash } from 'crypto';
import chokidar from 'chokidar';
import chalk from 'chalk';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');
const SYNC_LOG_DIR = path.join(ROOT_DIR, '.sync-logs');
const HASH_CACHE_FILE = path.join(ROOT_DIR, '.sync-cache.json');

/**
 * 计算文件的 MD5 哈希
 */
async function getFileHash(filePath) {
  try {
    const content = await fs.readFile(filePath);
    return createHash('md5').update(content).digest('hex');
  } catch (error) {
    return null;
  }
}

/**
 * 读取哈希缓存
 */
async function loadHashCache() {
  try {
    if (await fs.pathExists(HASH_CACHE_FILE)) {
      return await fs.readJson(HASH_CACHE_FILE);
    }
  } catch (error) {
    console.warn(chalk.yellow('⚠️  读取哈希缓存失败，将重新创建'));
  }
  return {};
}

/**
 * 保存哈希缓存
 */
async function saveHashCache(cache) {
  try {
    await fs.writeJson(HASH_CACHE_FILE, cache, { spaces: 2 });
  } catch (error) {
    console.error(chalk.red('保存哈希缓存失败:'), error.message);
  }
}

/**
 * 记录同步日志
 */
async function logSync(action, sourceFile, targetFile, details = '') {
  try {
    await fs.ensureDir(SYNC_LOG_DIR);
    const logFile = path.join(SYNC_LOG_DIR, `sync-${new Date().toISOString().split('T')[0]}.log`);
    const timestamp = new Date().toISOString();
    const logEntry = `[${timestamp}] ${action}: ${sourceFile} -> ${targetFile} ${details}\n`;
    await fs.appendFile(logFile, logEntry);
  } catch (error) {
    // 日志失败不影响同步
  }
}

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
 * 同步单个文件（基于内容哈希）
 */
async function syncFile(sourceRelPath, targetRelPath, force = false, hashCache = {}) {
  const sourcePath = path.join(ROOT_DIR, sourceRelPath);
  const targetPath = path.join(ROOT_DIR, targetRelPath);

  try {
    // 检查源文件是否存在
    if (!await fs.pathExists(sourcePath)) {
      console.log(chalk.yellow(`⚠️  源文件不存在: ${sourceRelPath}`));
      await logSync('ERROR', sourceRelPath, targetRelPath, '源文件不存在');
      return { synced: false, error: '源文件不存在' };
    }

    // 计算源文件哈希
    const sourceHash = await getFileHash(sourcePath);
    if (!sourceHash) {
      console.log(chalk.yellow(`⚠️  无法读取源文件: ${sourceRelPath}`));
      return { synced: false, error: '无法读取源文件' };
    }

    // 检查目标文件
    const targetExists = await fs.pathExists(targetPath);
    let shouldSync = force;

    if (!shouldSync && targetExists) {
      const targetHash = await getFileHash(targetPath);
      
      // 比较哈希值
      if (sourceHash !== targetHash) {
        // 检查是否是目标文件被误修改
        const cachedTargetHash = hashCache[targetRelPath];
        if (cachedTargetHash && cachedTargetHash !== targetHash && cachedTargetHash === sourceHash) {
          console.log(chalk.red(`⚠️  警告: ${targetRelPath} 可能被直接修改！`));
          console.log(chalk.yellow(`   应该在 ${sourceRelPath} 中修改，然后重新同步`));
          await logSync('WARNING', sourceRelPath, targetRelPath, '目标文件被直接修改');
        }
        shouldSync = true;
      }
    } else if (!targetExists) {
      shouldSync = true;
    }

    if (!shouldSync) {
      return { synced: false, skipped: true };
    }

    // 备份现有文件（如果存在且不同）
    if (targetExists) {
      const targetHash = await getFileHash(targetPath);
      if (targetHash !== sourceHash) {
        const backupDir = path.join(ROOT_DIR, '.sync-backups', new Date().toISOString().split('T')[0]);
        await fs.ensureDir(backupDir);
        const backupPath = path.join(backupDir, path.basename(targetPath) + '.bak');
        await fs.copy(targetPath, backupPath);
      }
    }

    // 确保目标目录存在
    await fs.ensureDir(path.dirname(targetPath));

    // 复制文件
    await fs.copy(sourcePath, targetPath, { overwrite: true });
    
    // 更新哈希缓存
    hashCache[targetRelPath] = sourceHash;
    hashCache[sourceRelPath] = sourceHash;
    
    const relTarget = path.relative(ROOT_DIR, targetPath);
    console.log(chalk.green(`✓ 已同步: ${relTarget}`));
    await logSync('SYNC', sourceRelPath, targetRelPath, `hash:${sourceHash.substring(0, 8)}`);
    
    return { synced: true, hash: sourceHash };
  } catch (error) {
    console.error(chalk.red(`✗ 同步失败: ${targetRelPath}`));
    console.error(chalk.red(`  错误: ${error.message}`));
    await logSync('ERROR', sourceRelPath, targetRelPath, error.message);
    return { synced: false, error: error.message };
  }
}

/**
 * 同步所有文件
 */
async function syncAll(force = false) {
  console.log(chalk.cyan('\n🔄 开始同步 shared_core...\n'));
  
  // 加载哈希缓存
  const hashCache = await loadHashCache();
  
  let totalSynced = 0;
  let totalSkipped = 0;
  let totalErrors = 0;
  const warnings = [];

  for (const category of Object.values(SYNC_CONFIG)) {
    for (const rule of category) {
      const { source, targets } = rule;
      
      for (const target of targets) {
        const result = await syncFile(source, target, force, hashCache);
        if (result.synced) {
          totalSynced++;
        } else if (result.error) {
          totalErrors++;
        } else {
          totalSkipped++;
        }
        
        if (result.warning) {
          warnings.push(result.warning);
        }
      }
    }
  }

  // 保存哈希缓存
  await saveHashCache(hashCache);

  // 显示总结
  console.log(chalk.cyan(`\n✅ 同步完成!`));
  console.log(chalk.green(`   已同步: ${totalSynced} 个文件`));
  console.log(chalk.gray(`   跳过: ${totalSkipped} 个文件`));
  if (totalErrors > 0) {
    console.log(chalk.red(`   错误: ${totalErrors} 个文件`));
  }
  if (warnings.length > 0) {
    console.log(chalk.yellow(`\n⚠️  警告: 发现 ${warnings.length} 个潜在问题`));
  }
  console.log('');
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

    // 加载哈希缓存
    const hashCache = await loadHashCache();

    // 找到对应的同步规则
    for (const category of Object.values(SYNC_CONFIG)) {
      for (const rule of category) {
        if (relPath === rule.source || relPath === rule.source.replace(/\//g, path.sep)) {
          for (const target of rule.targets) {
            await syncFile(rule.source, target, true, hashCache);
          }
        }
      }
    }

    // 保存哈希缓存
    await saveHashCache(hashCache);
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
