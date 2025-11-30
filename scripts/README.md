# Shared Core 同步工具

自动将 `shared_core` 中的文件同步到各个项目目录。

## 安装依赖

```bash
npm install
```

## 使用方法

### 1. 一次性同步

同步所有文件（仅同步已修改的文件）：

```bash
npm run sync
```

### 2. 强制同步

强制同步所有文件（忽略修改时间）：

```bash
npm run sync:force
```

### 3. 监听模式

自动监听文件变化并实时同步：

```bash
npm run sync:watch
```

在监听模式下，修改 `shared_core` 中的任何文件都会自动同步到目标目录。

### 4. 查看配置

查看当前的同步配置：

```bash
node scripts/sync-shared-core.js --config
```

## 同步规则

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
