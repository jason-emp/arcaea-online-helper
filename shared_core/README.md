# Shared Core Module

这是 Arcaea Helper 项目的共享核心模块，包含算法、数据和样式，可在 Chrome 扩展和 Flutter 应用之间共享。

## 目录结构

```
shared_core/
├── js/                      # JavaScript 核心模块
│   ├── arcaea-calculator.js     # PTT 计算算法
│   └── arcaea-data-loader.js    # 数据加载模块
├── css/                     # 共享样式
│   └── arcaea-styles.css        # Arcaea 页面样式
└── data/                    # 共享数据
    ├── ChartConstant.json       # 谱面定数数据
    └── Songlist.json            # 歌曲列表数据
```

## 模块说明

### arcaea-calculator.js

纯计算模块，不依赖任何外部库，包含以下静态方法：

- `calculatePlayPTT(score, constant)` - 计算单曲 PTT
- `getDisplayPTT(ptt)` - 获取显示 PTT（向下取整到两位小数）
- `calculateTargetScore(constant, currentScore, totalPTT)` - 计算目标分数
- `calculateRequiredConstants(currentPTT, best30PTTs, recent10PTTs)` - 计算推分所需定数
- `formatConstant(constant)` - 格式化定数显示
- `formatPTT(ptt)` - 格式化 PTT 显示
- `formatScore(score)` - 格式化分数显示

**使用示例**：

```javascript
// 计算单曲 PTT
const ptt = ArcaeaCalculator.calculatePlayPTT(9950000, 10.5);
console.log(ptt); // 12.25

// 计算目标分数
const target = ArcaeaCalculator.calculateTargetScore(10.5, 9900000, 12.50);
console.log(target); // 9905432 (示例)

// 格式化输出
console.log(ArcaeaCalculator.formatPTT(12.25678)); // "12.2568"
console.log(ArcaeaCalculator.formatScore(9950000)); // "9,950,000"
```

### arcaea-data-loader.js

数据加载和查询模块，支持两种初始化方式：

**方式1：从 URL 加载**（适用于 Chrome 扩展）

```javascript
const loader = new ArcaeaDataLoader();
await loader.init(
  'https://example.com/ChartConstant.json',
  'https://example.com/Songlist.json'
);
```

**方式2：从对象加载**（适用于 Flutter WebView）

```javascript
const loader = new ArcaeaDataLoader();
loader.initFromData(chartConstantObj, songListObj);
```

**查询方法**：

```javascript
// 查询谱面定数
const constant = loader.getChartConstant('Tempestissimo', 3); // Beyond
console.log(constant); // 11.0

// 支持的难度参数：
// - 数字：0(PST), 1(PRS), 2(FTR), 3(BYD), 4(ETR)
// - 字符串：'PST', 'PRS', 'FTR', 'BYD', 'ETR'（不区分大小写）
```

### arcaea-styles.css

Arcaea Online 页面的样式增强，包含：

- **响应式布局**：
  - 768px-1200px：双列布局
  - 1200px-1600px：三列布局
  - 1600px+：四列布局
  
- **卡片样式**：
  - 渐变背景和阴影效果
  - 根据难度等级（PST/PRS/FTR/BYD/ETR）调整颜色
  - 悬停效果

- **信息显示**：
  - 定数显示样式 (`.arcaea-chart-constant`)
  - 单曲 PTT 显示 (`.arcaea-play-ptt`)
  - 目标分数显示 (`.arcaea-target-score`)
  - 总 PTT 显示 (`.arcaea-total-ptt`)
  - 卡片序号 (`.arcaea-card-index`)

- **Pure/Far/Lost 优化**：
  - 纯文字显示，移除钻石图片
  - 渐变色彩区分判定类型

## 数据格式

### ChartConstant.json

```json
{
  "songid": [
    { "constant": 9.5 },  // PST
    { "constant": 10.0 }, // PRS
    { "constant": 10.5 }, // FTR
    { "constant": 11.0 }, // BYD
    null                   // ETR (如果没有)
  ]
}
```

### Songlist.json

```json
{
  "songs": [
    {
      "id": "songid",
      "title_localized": {
        "en": "Song Title",
        "ja": "曲名"
      },
      "difficulties": [...]
    }
  ]
}
```

## 环境兼容性

所有模块都使用标准 ES6+ 语法，兼容：
- 现代浏览器（Chrome 90+）
- Node.js 14+
- Flutter WebView (InAppWebView)

## 更新维护

### 更新定数数据

1. 获取最新的 ChartConstant.json 和 Songlist.json
2. 替换 `shared_core/data/` 中的文件
3. Chrome 扩展：重新加载扩展
4. Flutter 应用：运行 `flutter pub get` 重新打包资源

### 修改算法

1. 编辑 `shared_core/js/arcaea-calculator.js`
2. 确保修改不破坏现有 API
3. 更新文档说明
4. 测试 Chrome 扩展和 Flutter 应用

### 修改样式

1. 编辑 `shared_core/css/arcaea-styles.css`
2. 测试不同屏幕尺寸下的效果
3. 确保不影响原网页布局

## 许可证

MIT License - 详见项目根目录的 LICENSE 文件
