// 测试脚本 - 在浏览器控制台中运行以验证数据加载

(async function() {
  console.log('=== Arcaea Helper 测试脚本 ===\n');

  // 检查数据是否加载
  if (typeof window.arcaeaData === 'undefined') {
    console.error('❌ arcaeaData 未定义，扩展可能未正确加载');
    console.log('请检查：');
    console.log('1. 扩展是否已安装并启用');
    console.log('2. 是否在正确的页面（arcaea.lowiro.com）');
    console.log('3. 刷新页面重试');
    return;
  }
  
  console.log('✅ arcaeaData 已定义');
  
  // 检查数据是否已初始化
  if (window.arcaeaData.chartConstants === null) {
    console.warn('⚠️ 数据尚未加载，正在等待...');
    
    // 等待数据加载（最多10秒）
    let attempts = 0;
    while (window.arcaeaData.chartConstants === null && attempts < 100) {
      await new Promise(resolve => setTimeout(resolve, 100));
      attempts++;
    }
    
    if (window.arcaeaData.chartConstants === null) {
      console.error('❌ 数据加载超时');
      return;
    }
  }
  
  console.log('✅ Chart Constants 数据已加载');
  console.log('✅ Song List 数据已加载');
  
  // 测试一些常见曲目
  const testSongs = [
    { title: 'Tempestissimo', difficulty: 3 },
    { title: 'Grievous Lady', difficulty: 2 },
    { title: 'Fracture Ray', difficulty: 2 },
    { title: 'PRAGMATISM', difficulty: 3 },
    { title: 'Axiom of the End', difficulty: 2 }
  ];
  
  console.log('\n--- 测试曲目定数查询 ---');
  testSongs.forEach(song => {
    const constant = window.arcaeaData.getChartConstant(song.title, song.difficulty);
    const diffNames = ['Past', 'Present', 'Future', 'Beyond', 'Eternal'];
    if (constant !== null) {
      console.log(`✅ ${song.title} [${diffNames[song.difficulty]}]: ${window.arcaeaData.formatConstant(constant)}`);
    } else {
      console.log(`❌ ${song.title} [${diffNames[song.difficulty]}]: 未找到定数`);
    }
  });
  
  // 统计信息
  const songCount = window.arcaeaData.songList?.songs?.length || 0;
  const constantCount = Object.keys(window.arcaeaData.chartConstants || {}).length;
  
  console.log('\n--- 数据统计 ---');
  console.log(`曲目数量: ${songCount}`);
  console.log(`定数数据数量: ${constantCount}`);
  
  console.log('\n--- 快速测试函数 ---');
  console.log('你现在可以直接使用：');
  console.log('window.arcaeaData.getChartConstant("歌曲名", 难度)');
  console.log('例如：window.arcaeaData.getChartConstant("Tempestissimo", 3)');
  
  console.log('\n=== 测试完成 ===');
})();
