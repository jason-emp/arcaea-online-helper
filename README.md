# Arcaea Online Helper

[![Latest Release](https://img.shields.io/github/v/release/jason-emp/arcaea-online-helper?label=下载最新版本&style=for-the-badge&color=6750a4)](https://github.com/jason-emp/arcaea-online-helper/releases/latest)

一个增强 Arcaea Online 查分页面的 Flutter 跨平台移动应用，支持 Android 和 iOS。

> **注意**: Chrome 扩展版本已迁移到 [`legacy-chrome-extension`](https://github.com/jason-emp/arcaea-online-helper/tree/legacy-chrome-extension) 分支。

## 功能特性

- 📊 **显示谱面定数**：在曲目名称旁显示谱面定数
- 🎯 **计算单曲PTT**：显示每首歌曲的 PTT 值
- 📈 **计算总PTT**：基于 Best 30 和 Recent 10 计算精确总 PTT
- 🎯 **目标分数**：显示使显示 PTT +0.01 所需的目标分数
- 💎 **定数表格**：展示不同分数等级所需的最低谱面定数
- 🖼️ **B30/R10图片生成**：导出数据并生成精美的成绩图片
- 📱 **内置 WebView**：无需离开应用即可浏览 Arcaea Online
- ⚙️ **可自定义设置**：控制各项功能的显示
- 🔄 **自动注入**：自动在网页中注入增强脚本和样式

## 🚀 快速开始

### 环境要求

- Flutter SDK 3.0 或更高版本
- Android SDK (用于 Android 开发)
- Xcode (用于 iOS 开发，仅 macOS)

### 安装和运行

1. **克隆仓库**
   ```bash
   git clone https://github.com/jason-emp/arcaea-online-helper.git
   cd arcaea-online-helper/arcaea_helper_mobile
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **运行应用**
   ```bash
   # 调试模式
   flutter run

   # 发布构建
   flutter build apk  # Android
   flutter build ios  # iOS
   ```

### 主要依赖项

- `flutter_inappwebview: ^6.0.0` - WebView 组件
- `shared_preferences: ^2.2.2` - 本地存储
- `path_provider: ^2.1.1` - 文件路径访问
- `package_info_plus: ^8.0.0` - 应用信息获取
- `gal: ^2.3.0` - 图片保存到相册

## 使用说明

1. **启动应用**：打开应用后会自动加载 Arcaea Online 网页
2. **登录账号**：在内置浏览器中登录你的 Arcaea 账号
3. **查看成绩**：访问成绩页面，增强功能会自动生效
4. **调整设置**：点击设置按钮自定义显示选项
5. **生成图片**：导出数据并生成 B30/R10 成绩图片

## 技术架构

### WebView 集成

- 使用 `flutter_inappwebview` 提供完整的浏览器功能
- 自动注入 JavaScript 脚本和 CSS 样式
- 支持与网页的双向通信

### 资源管理

- 谱面定数数据存储在 `assets/data/ChartConstant.json`
- 曲目信息存储在 `assets/data/Songlist.json`
- 使用 `rootBundle.loadString()` 加载 JSON 数据
- 通过 `evaluateJavascript()` 将数据传递给网页

### 图片生成功能

应用内集成了 B30/R10 成绩图片生成功能：

1. 在成绩页面点击"生成图片"按钮
2. 应用会自动收集数据并生成精美的成绩图片
3. 图片包含玩家信息和完整的成绩卡片（8行5列布局）
4. 生成后可直接保存到相册或分享

详细使用说明请查看 [arcaea_helper_mobile/IMAGE_GENERATOR_GUIDE.md](arcaea_helper_mobile/IMAGE_GENERATOR_GUIDE.md)

## 项目结构

```
arcaea_helper_mobile/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── core/
│   │   └── constants.dart        # 常量定义
│   ├── models/                   # 数据模型
│   │   ├── app_settings.dart
│   │   ├── score_data.dart
│   │   └── b30r10_data.dart
│   ├── services/                 # 业务逻辑
│   │   ├── score_fetch_service.dart
│   │   ├── score_storage_service.dart
│   │   ├── image_generator_service.dart
│   │   ├── webview_script_manager.dart
│   │   └── update_service.dart
│   └── widgets/                  # UI 组件
│       ├── score_list_page.dart
│       ├── settings_panel.dart
│       └── settings_dialog.dart
├── assets/
│   ├── data/                     # 谱面数据
│   │   ├── ChartConstant.json
│   │   └── Songlist.json
│   └── fonts/                    # 字体文件
├── web/
│   ├── js/                       # JavaScript 脚本
│   │   ├── arcaea-calculator.js
│   │   ├── arcaea-data-loader.js
│   │   └── flutter-content.js
│   └── css/
│       └── arcaea-styles.css     # 样式文件
└── pubspec.yaml                  # 依赖配置
```

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

### 开发环境设置

1. **安装 Flutter**：访问 [Flutter 官网](https://flutter.dev/docs/get-started/install) 安装 Flutter SDK

2. **配置编辑器**：推荐使用 VS Code 或 Android Studio

3. **克隆项目**
   ```bash
   git clone https://github.com/jason-emp/arcaea-online-helper.git
   cd arcaea-online-helper/arcaea_helper_mobile
   ```

4. **安装依赖**
   ```bash
   flutter pub get
   ```

### 开发工作流

1. **修改代码**
   - 算法相关：编辑 `web/js/arcaea-calculator.js`
   - 样式相关：编辑 `web/css/arcaea-styles.css`
   - 数据更新：替换 `assets/data/` 中的 JSON 文件
   - Flutter 代码：编辑 `lib/` 中的相关文件

2. **测试**
   ```bash
   # 热重载
   在运行中的应用中按 'r'
   
   # 热重启
   在运行中的应用中按 'R'
   
   # 完全重新构建
   flutter run
   ```

3. **调试**
   ```bash
   # 查看日志
   flutter logs
   
   # 连接调试器
   flutter attach
   ```

### 构建发布版本

**Android**:
```bash
# APK
flutter build apk --release

# App Bundle (推荐用于 Google Play)
flutter build appbundle --release
```

**iOS**:
```bash
flutter build ios --release
```

### 更新数据文件

当 Arcaea 更新曲目或谱面定数时：

1. 获取最新的 `ChartConstant.json` 和 `Songlist.json`
2. 替换 `assets/data/` 中的对应文件
3. 运行 `flutter pub get` 更新资源
4. 测试并发布新版本

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 致谢

- 感谢 Arcaea 社区维护的谱面定数数据
- 感谢所有贡献者和用户的支持

## 更新日志

### v2.0.0 (2024-12-08)
- 🔄 重构为纯 Flutter 项目
- 🗑️ 移除 Chrome 扩展（已迁移到 legacy-chrome-extension 分支）
- 🗑️ 移除 Node.js 图片生成脚本
- 📱 专注于移动端体验优化
- 📝 更新项目文档和结构

### v1.0.1
- ✨ 添加 B30+R10 图片的生成导出功能
- 🎨 优化 UI 和布局
- 🐛 修复注入网页的问题
- 🔧 修复其他问题

### v0.2.0
- ✨ 重构为多端架构，支持 Chrome 扩展和 Flutter 应用
- 📦 提取共享核心模块
- 🎨 优化代码结构，提高可维护性

### v0.1.0
- 🎉 首次发布
- 📊 支持 Chrome 扩展

## 常见问题

**Q: Chrome 扩展版本还维护吗？**  
A: Chrome 扩展代码已迁移到 [`legacy-chrome-extension`](https://github.com/jason-emp/arcaea-online-helper/tree/legacy-chrome-extension) 分支，但不再积极维护。建议使用 Flutter 移动应用。

**Q: 如何更新谱面数据？**  
A: 替换 `arcaea_helper_mobile/assets/data/` 中的 JSON 文件，然后运行 `flutter pub get` 重新构建资源。

**Q: 支持哪些平台？**  
A: 目前支持 Android 和 iOS。理论上也支持 Windows、macOS 和 Linux 桌面平台，但未经充分测试。

**Q: 如何报告问题或提出建议？**  
A: 请通过 [GitHub Issues](https://github.com/jason-emp/arcaea-online-helper/issues) 提交。

**Q: 为什么要移除 Chrome 扩展？**  
A: 为了简化项目结构，专注于移动端开发。Chrome 扩展的功能已完整保留在单独的分支中。

## 贡献

欢迎提交 Issue 和 Pull Request！

贡献指南：
1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的修改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

## 联系方式

如有问题或建议，请通过 [GitHub Issues](https://github.com/jason-emp/arcaea-online-helper/issues) 联系。
