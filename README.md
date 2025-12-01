# Arcaea Online Helper

[![Latest Release](https://img.shields.io/github/v/release/jason-emp/arcaea-online-helper?label=下载最新版本&style=for-the-badge&color=6750a4)](https://github.com/jason-emp/arcaea-online-helper/releases/latest)

一个增强 Arcaea Online 查分页面的跨平台工具，支持 Android、 iOS 和 Chrome 扩展（Windows、 macOS、 Linux）。

## 功能特性

- 📊 **显示谱面定数**：在曲目名称旁显示谱面定数
- 🎯 **计算单曲PTT**：显示每首歌曲的 PTT 值
- 📈 **计算总PTT**：基于 Best 30 和 Recent 10 计算精确总 PTT
- 🎯 **目标分数**：显示使显示 PTT +0.01 所需的目标分数
- 💎 **定数表格**：展示不同分数等级所需的最低谱面定数
- 🎨 **双列/三列布局**：PC 端优化显示
- 🖼️ **B30/R10图片生成**：导出数据并生成精美的成绩图片（8行5列）
- ⚙️ **可自定义设置**：控制各项功能的显示

## 🚀 快速开始

### 自动同步工具

本项目使用 Node.js 自动同步工具，文件保存在各自目录中，但会自动从 `shared_core` 同步更新。

```bash
# 安装依赖
npm install

# 开发模式（监听文件变化，自动同步）
npm run sync:watch

# 手动同步
npm run sync
```

**⚠️ 重要**: 始终在 `shared_core/` 中修改代码，同步工具会自动复制到各个项目！

详细说明请查看 [scripts/README.md](scripts/README.md)

---



### 🔄 自动同步说明

- **源文件**: 在 `shared_core/` 中修改
- **目标文件**: 自动同步到 `chrome_extension/` 和 `arcaea_helper_mobile/`
- **同步方式**: 运行 `npm run sync:watch` 自动监听变化


## 安装和使用

### Chrome 扩展

1. 下载或克隆本仓库
2. 运行 `npm install && npm run sync` 同步文件
3. 打开 Chrome，访问 `chrome://extensions/`
4. 启用"开发者模式"
5. 点击"加载已解压的扩展程序"
6. 选择 `chrome_extension` 文件夹
7. 访问 https://arcaea.lowiro.com/*/profile/potential 即可使用

### 设置选项

点击扩展图标可打开设置面板：
- **显示图表**：显示/隐藏 Best 30 和 Recent 10 的 PTT 变化图表
- **显示定数**：在曲目名称旁显示谱面定数
- **显示单曲PTT**：显示每首歌曲的 PTT 值
- **显示目标分数**：显示推分目标分数
- **显示下载按钮**：显示/隐藏截图下载按钮
- **导出数据**：导出 B30/R10 数据为 JSON 文件，用于生成图片

### 图片生成功能

Chrome扩展支持导出 B30/R10 数据并生成精美的成绩图片：

1. **导出数据**：在扩展设置面板点击"导出B30/R10数据"按钮
2. **生成图片**：运行图片生成脚本
   ```bash
   npm install  # 首次使用需要安装依赖
   npm run generate-image <导出的JSON文件路径>
   ```
3. **查看结果**：生成的PNG图片包含玩家信息和8行5列的歌曲卡片

详细说明请查看 [IMAGE_GENERATOR_README.md](IMAGE_GENERATOR_README.md)

### 移动应用

1. 确保已安装 Flutter SDK
2. 运行 `npm install && npm run sync` 同步文件
3. 进入 `arcaea_helper_mobile` 目录
4. 运行 `flutter pub get` 安装依赖
5. 运行 `flutter run` 启动应用

**依赖项**：
- `flutter_inappwebview: ^6.0.0` - WebView 组件
- `shared_preferences: ^2.2.2` - 本地存储
- `path_provider: ^2.1.1` - 路径访问

**特性**：
- 内置 WebView 浏览 Arcaea Online
- 自动注入 shared_core 脚本和样式
- 内置设置面板，无需离开应用
- 支持刷新和导航

## 技术架构

### 代码共享策略

**新架构**：
1. **源文件**: 所有共享代码存放在 `shared_core/`
2. **同步工具**: 使用 Node.js 脚本自动同步到各项目
3. **独立部署**: 每个项目拥有自己的文件副本，互不依赖
4. **开发流程**: 修改 `shared_core/` → 自动同步 → 测试各项目

**优势**：
- ✅ 文件独立，Chrome 扩展无需加载整个项目
- ✅ 各项目可独立部署和打包
- ✅ 保持代码共享的便利性
- ✅ 避免相对路径引用问题

### 同步规则

| 源文件 | Chrome 扩展 | Flutter 应用 |
|--------|------------|-------------|
| `shared_core/js/*.js` | `chrome_extension/js/*.js` | `arcaea_helper_mobile/web/js/*.js` |
| `shared_core/css/*.css` | `chrome_extension/css/*.css` | `arcaea_helper_mobile/web/css/*.css` |
| `shared_core/data/*.json` | `chrome_extension/data/*.json` | `arcaea_helper_mobile/assets/data/*.json` |

### Chrome 扩展实现

- 使用 `chrome.runtime.getURL()` 加载 shared_core 资源
- Manifest V3 配置 `web_accessible_resources` 允许页面访问资源
- Content Script 引入 shared_core 模块后执行业务逻辑

### Flutter 应用实现

- 使用 `rootBundle.loadString()` 加载 shared_core 资源
- 通过 `evaluateJavascript()` 注入脚本到 WebView
- 将 JSON 数据直接传递给 JavaScript 环境

## 算法说明

### PTT 计算公式

```
单曲PTT =
  - score >= 10,000,000: constant + 2
  - score >= 9,800,000:  constant + 1 + (score - 9,800,000) / 200,000
  - score < 9,800,000:   constant + (score - 9,500,000) / 300,000
```

### 总PTT 计算

```
总PTT = (Best 30 单曲PTT之和 + Recent 10 单曲PTT之和) / 40
显示PTT = floor(总PTT * 100) / 100
```

### 目标分数计算

使用二分搜索找到最小分数 S，使得：
```
新总PTT = 旧总PTT - 旧单曲PTT/40 + 新单曲PTT/40
floor(新总PTT * 100) / 100 >= floor(旧总PTT * 100) / 100 + 0.01
```

### 推分定数计算

计算使显示 PTT +0.01 所需的最低谱面定数，考虑三种场景：
- 场景A：仅替换 Recent 10 最低值
- 场景B：仅替换 Best 30 最低值
- 场景C：同时替换两者

## 开发指南

### 开发工作流

1. **启动监听模式**
   ```bash
   npm run sync:watch
   ```

2. **修改代码**
   - 在 `shared_core/` 中修改算法、样式或数据
   - 文件会自动同步到各个项目

3. **测试**
   - Chrome 扩展：重新加载扩展，刷新网页
   - Flutter 应用：热重载或重启应用

### 修改算法

编辑 `shared_core/js/arcaea-calculator.js`：

### 修改样式

编辑 `shared_core/css/arcaea-styles.css`

### 更新数据

替换 `shared_core/data/` 中的 JSON 文件，然后运行 `npm run sync`

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 致谢

- 感谢 Arcaea 社区维护的谱面定数数据
- 感谢所有贡献者

## 更新日志

### v1.0.1
- ✨ 添加 B30+R10 图片的生成导出功能
- 🎨 优化UI和布局
- 🌐 Chrome扩展采用Material Design设置页
- 🐛 修复有概率不能正确注入网页的恶性bug
- 🔧 修复其他问题

### v0.2.0
- ✨ 重构为多端架构，支持 Chrome 扩展和基于 Flutter 的 Android / iOS 应用
- 📦 提取共享核心模块 (shared_core)
- 🔧 新增 Node.js 自动同步工具
- 🎨 优化代码结构，提高可维护性

### v0.1.0
- 🎉 首次发布
- 📊 支持 Chrome 扩展

## 常见问题

**Q: 为什么需要运行同步工具？**  
A: 为了保持各项目文件独立，同时共享核心代码。这样 Chrome 扩展和 Flutter 应用都可以独立部署。

**Q: 我可以直接修改 chrome_extension 中的文件吗？**  
A: 不推荐，因为下次同步会覆盖你的修改。请始终在 `shared_core/` 中修改。

**Q: 同步工具会覆盖我的自定义修改吗？**  
A: 同步工具只同步特定文件（算法、样式、数据），不会影响各项目特有的文件（如 manifest.json、main.dart 等）。

**Q: Flutter 应用如何更新数据？**  
A: 在 `shared_core/data/` 中替换 JSON 文件，运行 `npm run sync`，然后 `flutter pub get` 重新构建资源。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 联系方式

如有问题或建议，请通过 GitHub Issues 联系。
