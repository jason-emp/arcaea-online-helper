# Arcaea B30/R10 图片生成功能

## 功能说明

这个功能可以将你的Arcaea Best 30 和 Recent 10 数据生成为一张精美的图片，包含：

- **顶部玩家信息区域**：显示玩家名、总PTT、B30平均、R10平均
- **8行5列的歌曲卡片**：每张卡片包含
  - 歌曲名称
  - 难度标签（颜色区分）
  - 分数
  - 谱面定数
  - 单曲PTT
  - 曲绘背景（透明显示）
  - 排名标记（#1-30 或 R1-10）

## 使用步骤

### 第一步：从Chrome扩展导出数据

1. 打开 [Arcaea Online](https://arcaea.lowiro.com/) 并登录
2. 进入你的查分页面（Profile - Potential）
3. 等待扩展加载完所有数据（定数、PTT等应该都显示出来）
4. 点击Chrome扩展图标，打开设置面板
5. 在"数据导出"部分，点击下载按钮 📥
6. 保存JSON文件到你的电脑

### 第二步：安装依赖

首次使用需要安装Node.js依赖：

```bash
npm install
```

> **注意**：`canvas` 包可能需要一些系统依赖。如果安装失败，请参考下方的系统依赖安装指南。

### 第三步：生成图片

**方法一：自动检测（推荐）**

将导出的JSON文件放在项目根目录，然后运行：

```bash
npm run generate-image
```

脚本会自动：
- 搜索当前目录下的所有JSON文件
- 验证文件格式
- 如果只有一个有效文件，直接使用
- 如果有多个文件，显示选择菜单让你选择

**方法二：手动指定文件**

运行以下命令：

```bash
npm run generate-image <你的JSON文件路径>
```

或者直接使用：

```bash
node scripts/generate-b30r10-image.js <你的JSON文件路径>
```

**示例：**

```bash
# 自动检测（最简单）
npm run generate-image

# 如果JSON文件在项目根目录
npm run generate-image arcaea-b30r10-2024-12-01.json

# 如果JSON文件在其他位置
npm run generate-image ~/Downloads/arcaea-b30r10-2024-12-01.json
```

### 第四步：查看生成的图片

生成的PNG图片会保存在当前目录，文件名格式为：

```
arcaea-b30r10-<玩家名>-<时间戳>.png
```

## 系统依赖

### macOS

```bash
brew install pkg-config cairo pango libpng jpeg giflib librsvg
```

### Ubuntu/Debian

```bash
sudo apt-get install build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev
```

### Windows

Windows用户可以使用预编译的二进制文件，通常 `npm install` 会自动处理。如果遇到问题，请参考 [node-canvas 文档](https://github.com/Automattic/node-canvas/wiki/Installation:-Windows)。

## 输出图片说明

- **尺寸**：2400 x 3600 像素（2:3比例）
- **格式**：PNG
- **布局**：
  - 顶部280px：玩家信息区域
  - 下方：8行5列的卡片网格（共40张卡片位置）
  - Best 30 卡片在前6行
  - Recent 10 卡片在后2行

## 配置选项

如果你想自定义图片样式，可以编辑 `scripts/generate-b30r10-image.js` 文件中的 `CONFIG` 对象：

```javascript
const CONFIG = {
  // 画布尺寸
  canvasWidth: 2400,
  canvasHeight: 3600,
  
  // 卡片布局
  rows: 8,
  cols: 5,
  cardWidth: 440,
  cardHeight: 380,
  
  // 颜色方案
  colors: {
    background: '#1a1a2e',
    // ... 更多颜色设置
  },
  
  // 字体大小
  fontSize: {
    playerName: 48,
    // ... 更多字体设置
  }
};
```

## 常见问题

### Q: 我不想每次都输入文件路径怎么办？

A: 直接运行 `npm run generate-image`！脚本会自动搜索当前目录下的所有JSON文件并让你选择。如果只有一个有效文件，会自动使用它。

### Q: 生成的图片中曲绘无法显示？

A: 这是正常的，因为曲绘URL可能需要登录才能访问，或者有防盗链保护。脚本会继续生成图片，只是背景会是纯色而已。

### Q: 可以修改图片的颜色主题吗？

A: 可以！编辑 `scripts/generate-b30r10-image.js` 中的 `CONFIG.colors` 对象即可。

### Q: 生成的图片文件太大？

A: PNG格式保证了图片质量。如果需要更小的文件，可以使用图片压缩工具（如 TinyPNG）进行后期压缩。

### Q: 能不能只生成B30或只生成R10？

A: 可以手动编辑导出的JSON文件，删除不需要的部分（`best30` 或 `recent10` 数组）。脚本会自动验证并处理。

### Q: 脚本提示"未找到任何JSON文件"？

A: 请确保：
1. 你在项目根目录运行命令
2. JSON文件在当前目录
3. 文件名以 `.json` 结尾
4. 或者使用 `npm run generate-image <文件路径>` 手动指定文件

## JSON数据格式说明

导出的JSON文件包含以下结构：

```json
{
  "player": {
    "username": "玩家名",
    "totalPTT": 12.5000,
    "best30Avg": 12.6000,
    "recent10Avg": 12.1000,
    "exportDate": "2024-12-01T12:00:00.000Z"
  },
  "best30": [
    {
      "songTitle": "歌曲名",
      "difficulty": "FTR",
      "difficultyIndex": 2,
      "score": 10000000,
      "constant": 11.0,
      "playPTT": 13.0000,
      "coverUrl": "https://...",
      "rank": 1
    }
    // ... 更多卡片
  ],
  "recent10": [
    // 结构同上
  ]
}
```

## 技术细节

- **Canvas渲染**：使用 `node-canvas` 库进行服务端图片渲染
- **异步图片加载**：支持从URL下载曲绘（需要网络连接）
- **容错处理**：如果某张曲绘加载失败，会继续生成其他部分
- **渐变效果**：使用Canvas渐变实现美观的视觉效果
- **圆角卡片**：自定义圆角矩形绘制函数

## 许可证

MIT License - 可自由使用和修改
