# Scripts 目录说明

本目录包含项目的实用脚本工具。

## 脚本列表

### 1. sync-shared-core.js - 共享代码同步工具

自动将 `shared_core` 中的文件同步到各个项目目录。

**使用方法：**

```bash
# 一次性同步
npm run sync

# 强制同步所有文件
npm run sync:force

# 监听模式（开发推荐）
npm run sync:watch
```

详细说明请查看同步规则部分。

### 2. generate-b30r10-image.js - B30/R10图片生成器

将从Chrome扩展导出的JSON数据生成为精美的成绩图片。

**使用方法：**

```bash
# 首次使用安装依赖
npm install

# 生成图片
npm run generate-image <JSON文件路径>

# 或直接运行
node scripts/generate-b30r10-image.js <JSON文件路径>
```

**示例：**

```bash
npm run generate-image ./arcaea-b30r10-2024-12-01.json
```

**输出：**
- 2400x3600像素的PNG图片
- 8行5列的歌曲卡片布局
- 包含玩家信息、分数、定数、PTT等完整数据

详细说明请查看 [IMAGE_GENERATOR_README.md](../IMAGE_GENERATOR_README.md)

---

## 安装依赖

```bash
npm install
```

## Shared Core 同步工具详细说明

### 同步规则

### JavaScript 文件

- `shared_core/js/arcaea-calculator.js` → 
  - `chrome_extension/js/arcaea-calculator.js`
  - `arcaea_helper_mobile/web/js/arcaea-calculator.js`

- `shared_core/js/arcaea-data-loader.js` → 
  - `chrome_extension/js/arcaea-data-loader.js`
  - `arcaea_helper_mobile/web/js/arcaea-data-loader.js`

- `shared_core/js/flutter-content.js` → 
  - `arcaea_helper_mobile/web/js/flutter-content.js`

### CSS 文件

- `shared_core/css/arcaea-styles.css` → 
  - `chrome_extension/css/arcaea-styles.css`
  - `arcaea_helper_mobile/web/css/arcaea-styles.css`

### 数据文件

- `shared_core/data/ChartConstant.json` → 
  - `chrome_extension/data/ChartConstant.json`
  - `arcaea_helper_mobile/assets/data/ChartConstant.json`

- `shared_core/data/Songlist.json` → 
  - `chrome_extension/data/Songlist.json`
  - `arcaea_helper_mobile/assets/data/Songlist.json`

## 工作流程建议

1. **开发时**：运行 `npm run sync:watch` 启动监听模式
2. **在 `shared_core` 中修改代码**：文件会自动同步到各个项目
3. **提交前**：运行 `npm run sync` 确保所有文件已同步
4. **部署前**：运行 `npm run sync:force` 强制同步所有文件

## 自定义同步规则

编辑 `scripts/sync-shared-core.js` 中的 `SYNC_CONFIG` 对象来添加或修改同步规则。

```javascript
const SYNC_CONFIG = {
  js: [
    {
      source: 'shared_core/js/your-file.js',
      targets: [
        'target1/js/your-file.js',
        'target2/js/your-file.js'
      ]
    }
  ]
};
```
