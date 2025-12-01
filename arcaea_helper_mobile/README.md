# 🎵 Arcaea Helper Mobile

一个基于 Flutter 的跨平台移动应用，用于增强 Arcaea Online 查分页面体验，支持 Android 和 iOS 平台。提供谱面定数显示、PTT 计算、推分辅助等多项实用功能。

**目前定数表适用于移动版 v6.11.0。**

---

## ✨ 功能特点

### 📊 核心功能
- 🎯 **谱面定数显示** - 在曲目名称旁显示定数，如 `Tempestissimo (11.3)`
- 💎 **单曲 PTT 计算** - 实时计算并显示每首歌的 Potential
- 🎓 **精确总 PTT** - 基于 Best 30 和 Recent 10 计算准确的总 PTT 值
- 🎯 **推分目标提示** - 显示使显示 PTT +0.01 所需的目标分数
- 📈 **定数需求卡片** - 展示达到 +0.01 PTT 所需的最低谱面定数（EX+、EX、995W 等）
- 🔢 **曲目编号** - 自动为 Best 30 (#1-#30) 和 Recent 10 (R1-R10) 添加序号
- 📍 **分隔线** - 在 Best 30 和 Recent 10 之间添加视觉分隔
- 🖼️ **图片生成** - 一键生成精美的 B30/R10 图片（2400x3900高分辨率）

### 🎨 图片生成功能 ✨新增
- 📸 **一键生成** - 直接在手机上生成精美的 B30/R10 图片
- 🎨 **高清输出** - 2400x3900 像素，PNG 格式
- 📊 **完整信息** - 包含所有歌曲卡片、定数、PTT、目标分数
- 🖼️ **精美设计** - 曲绘背景、渐变效果、专业排版
- 📱 **即时分享** - 生成完成后直接分享到社交媒体或保存
- ⚡ **自动提取** - 无需手动导出，自动从页面获取数据
- 📈 **实时进度** - 显示生成进度，清晰了解处理状态

👉 [查看图片生成详细指南](./IMAGE_GENERATOR_GUIDE.md) | [快速开始](./QUICKSTART_IMAGE_GENERATOR.md)

### 📱 移动端特性
- 📲 **内置 WebView** - 无需切换应用，直接在应用内浏览 Arcaea Online
- ⚙️ **内置设置面板** - 点击设置按钮即可调整显示选项，无需离开应用
- 🔄 **自动注入** - 页面加载时自动注入脚本和样式
- 💾 **本地存储** - 设置自动保存，重启应用后保持
- 🔒 **离线数据** - 谱面定数和曲目列表内置于应用，无需网络加载

### 🎮 兼容性
- ✅ **支持所有难度** - Past / Present / Future / Beyond / Eternal
- 🔄 **动态更新** - 自动处理页面路由变化和动态加载
- 🌍 **多语言支持** - 支持英文和日文曲目名称
- 📱 **跨平台** - Android 和 iOS 通用

### ⚡ 技术特性
- 🚀 **性能优化** - Flutter 原生性能，流畅体验
- 🔒 **隐私安全** - 完全本地运行，不收集任何数据
- 🛡️ **稳定可靠** - 基于 shared_core 核心模块，与 Chrome 扩展共享逻辑

---

## 🚀 快速开始

### 前置要求

⚠️ **重要：需要用户订阅了 Arcaea Online**

本应用仅适用于已订阅 Arcaea Online 服务的用户。如果您还未订阅，请访问 [Arcaea 官网](https://arcaea.lowiro.com/) 进行订阅。

**开发环境要求：**
- Flutter SDK >= 3.10.1
- Dart SDK >= 3.10.1
- Android Studio / Xcode（根据目标平台）
- Node.js（用于运行同步工具）

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone <repository-url>
   cd arcaea-online-helper
   ```

2. **同步共享代码**
   ```bash
   npm install
   npm run sync
   ```
   这会将 `shared_core/` 中的核心代码同步到移动应用。

3. **安装 Flutter 依赖**
   ```bash
   cd arcaea_helper_mobile
   flutter pub get
   ```

4. **运行应用**
   ```bash
   # Android
   flutter run

   # iOS (需要 macOS)
   flutter run -d ios

   # 选择特定设备
   flutter devices
   flutter run -d <device-id>
   ```

### 打包发布

**Android APK:**
```bash
flutter build apk --release
# APK 位于: build/app/outputs/flutter-apk/app-release.apk
```

**Android App Bundle (推荐用于 Google Play):**
```bash
flutter build appbundle --release
# AAB 位于: build/app/outputs/bundle/release/app-release.aab
```

**iOS (需要 Apple Developer 账号):**
```bash
flutter build ios --release
# 然后在 Xcode 中打开 ios/Runner.xcworkspace 进行签名和上传
```

---

## 📱 使用指南

### 首次使用

1. 启动应用后，会自动打开 Arcaea Online 网站
2. 登录你的 Arcaea 账号
3. 导航到 Profile -> Potential 页面
4. 应用会自动显示：
   - 谱面定数（灰色）
   - 单曲 PTT（紫色粗体）
   - 推分目标分数（绿色）
   - 总 PTT（用户名旁）
   - 定数需求卡片（B1 前方）

### ⚙️ 设置面板

点击右上角的设置图标（⚙️）打开设置面板，可以自定义：

| 设置项 | 说明 | 默认值 |
|--------|------|--------|
| **显示图表** | 显示/隐藏 Best 30/Recent 10 的 PTT 变化图表 | 隐藏 |
| **显示定数** | 在曲目名称旁显示谱面定数 | 显示 |
| **显示单曲PTT** | 显示每首歌曲的 PTT 值 | 显示 |
| **显示目标分数** | 显示推分目标分数 | 显示 |
| **显示下载按钮** | 显示/隐藏截图下载和背景选择按钮 | 显示 |

💡 **提示：** 设置会自动保存到本地，下次打开应用时会自动应用。

### 刷新页面

点击右上角的刷新按钮（🔄）可以重新加载当前页面。

---

## 🛠️ 技术架构

### 核心依赖

```yaml
dependencies:
  flutter_inappwebview: ^6.0.0    # 内置 WebView 组件
  shared_preferences: ^2.2.2      # 本地设置存储
  path_provider: ^2.1.1           # 文件路径访问
  image: ^4.1.7                   # 图片处理（图片生成）
  http: ^1.2.0                    # 网络请求（加载曲绘）
  permission_handler: ^11.3.0     # 权限管理
  share_plus: ^7.2.1              # 分享功能
```

### 代码共享策略

本应用使用 **shared_core** 模块共享核心逻辑：

```
shared_core/
  ├── js/
  │   ├── arcaea-calculator.js      # PTT 计算逻辑
  │   ├── arcaea-data-loader.js     # 数据加载模块
  │   └── flutter-content.js        # Flutter 内容脚本
  ├── css/
  │   └── arcaea-styles.css         # 样式表
  └── data/
      ├── ChartConstant.json        # 谱面定数数据
      └── Songlist.json             # 曲目列表数据
```

**同步流程：**
1. 在项目根目录运行 `npm run sync`
2. 脚本自动复制文件：
   - `shared_core/js/*.js` → `arcaea_helper_mobile/web/js/`
   - `shared_core/css/*.css` → `arcaea_helper_mobile/web/css/`
   - `shared_core/data/*.json` → `arcaea_helper_mobile/assets/data/`
3. Flutter 通过 `rootBundle.loadString()` 加载资源

### 脚本注入流程

```dart
1. WebView 加载 Arcaea Online 页面
   ↓
2. onLoadStop 回调触发
   ↓
3. 检测是否为 /profile/potential 页面
   ↓
4. 依次注入：
   - CSS 样式
   - arcaea-calculator.js
   - arcaea-data-loader.js
   - 初始化数据 (ChartConstant.json, Songlist.json)
   - 设置配置
   - flutter-content.js
   ↓
5. 触发页面处理函数
   ↓
6. 显示增强功能
```

---

## 📊 算法说明

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

---

## 🔧 开发指南

### 开发工作流

1. **启动同步监听**
   ```bash
   # 在项目根目录
   npm run sync:watch
   ```

2. **修改共享代码**
   - 在 `shared_core/` 中修改算法、样式或数据
   - 文件会自动同步到 `arcaea_helper_mobile/`

3. **热重载测试**
   ```bash
   # 在 arcaea_helper_mobile 目录
   flutter run
   # 代码修改后按 'r' 热重载，按 'R' 热重启
   ```

4. **调试**
   ```bash
   # 查看日志
   flutter logs

   # Chrome DevTools (需要在 Android 上启用 WebView 调试)
   chrome://inspect
   ```

### 修改核心逻辑

⚠️ **重要：** 始终在 `shared_core/` 中修改，而不是直接修改 `arcaea_helper_mobile/web/` 或 `arcaea_helper_mobile/assets/`！

**修改算法：**
```bash
# 编辑
vim shared_core/js/arcaea-calculator.js

# 同步
npm run sync

# 测试
cd arcaea_helper_mobile
flutter run
```

**修改样式：**
```bash
# 编辑
vim shared_core/css/arcaea-styles.css

# 同步和测试
npm run sync
cd arcaea_helper_mobile
flutter run
```

**更新数据：**
```bash
# 替换数据文件
cp new-data/ChartConstant.json shared_core/data/
cp new-data/Songlist.json shared_core/data/

# 同步
npm run sync

# 重新获取资源
cd arcaea_helper_mobile
flutter pub get
flutter run
```

### 调试技巧

**WebView 控制台日志：**
```dart
// 在 main.dart 中已配置
onConsoleMessage: (controller, consoleMessage) {
  debugPrint('[WebView Console] ${consoleMessage.message}');
}
```

**检查脚本注入：**
```bash
# 运行应用并查看日志
flutter run
# 查找 "[Arcaea Helper]" 相关日志
```

**常见问题排查：**
1. 定数未显示 → 检查数据文件是否同步
2. 样式异常 → 检查 CSS 是否注入成功
3. PTT 计算错误 → 查看控制台错误信息

---

## ❓ 常见问题

<details>
<summary><strong>Q1: 应用无法显示定数/PTT？</strong></summary>

**解决步骤：**
1. 确认已运行 `npm run sync` 同步代码
2. 重启应用
3. 在设置面板中确认相关选项已启用
4. 刷新页面（点击刷新按钮）
5. 查看应用日志：`flutter logs`
</details>

<details>
<summary><strong>Q2: 如何更新谱面定数数据？</strong></summary>

**更新步骤：**
1. 访问 [Arcaea 中文维基](https://arcwiki.mcd.blue/) 获取最新数据：
   - [ChartConstant.json](https://arcwiki.mcd.blue/index.php?title=Template:ChartConstant.json&action=edit)
   - [Songlist.json](https://arcwiki.mcd.blue/index.php?title=Template:Songlist.json&action=edit)

2. 替换 `shared_core/data/` 中的文件

3. 运行同步：
   ```bash
   npm run sync
   cd arcaea_helper_mobile
   flutter pub get
   flutter run
   ```
</details>

<details>
<summary><strong>Q3: iOS 构建失败怎么办？</strong></summary>

**常见解决方案：**

```bash
# 清理缓存
cd ios
pod deintegrate
pod install
cd ..

# 重新构建
flutter clean
flutter pub get
flutter build ios
```

如果仍有问题，检查：
- Xcode 版本是否最新
- CocoaPods 是否正确安装
- iOS Deployment Target 是否兼容
</details>

<details>
<summary><strong>Q4: Android 构建 APK 体积太大？</strong></summary>

**优化方案：**

```bash
# 构建分架构 APK
flutter build apk --split-per-abi --release

# 这会生成多个 APK：
# - app-armeabi-v7a-release.apk (ARM 32-bit)
# - app-arm64-v8a-release.apk (ARM 64-bit)
# - app-x86_64-release.apk (x86 64-bit)
```

或使用 App Bundle（Google Play 推荐）：
```bash
flutter build appbundle --release
```
</details>

<details>
<summary><strong>Q5: 设置无法保存？</strong></summary>

**检查项：**
1. 确认 `shared_preferences` 依赖已正确安装
2. Android：检查应用权限
3. iOS：检查是否有写入限制

**测试：**
```dart
// 在 main.dart 中添加日志
debugPrint('[Settings] 保存: showCharts=$showCharts');
```
</details>

<details>
<summary><strong>Q6: 应用崩溃或白屏？</strong></summary>

**调试步骤：**
```bash
# 查看详细日志
flutter run --verbose

# 检查错误堆栈
# FlutterError.onError 已在 main.dart 中配置
```

**常见原因：**
- WebView 初始化失败
- 资源文件未正确加载
- JavaScript 注入错误
</details>

---

## 📦 项目结构

```
arcaea_helper_mobile/
├── android/                    # Android 平台配置
├── ios/                        # iOS 平台配置
├── lib/
│   ├── main.dart              # 主应用代码
│   ├── models/
│   │   └── b30r10_data.dart   # B30/R10 数据模型
│   └── services/
│       ├── image_generator_config.dart   # 图片生成配置
│       └── image_generator_service.dart  # 图片生成服务
├── web/                       # WebView 资源（从 shared_core 同步）
│   ├── js/
│   │   ├── arcaea-calculator.js
│   │   ├── arcaea-data-loader.js
│   │   └── flutter-content.js
│   └── css/
│       └── arcaea-styles.css
├── assets/                    # 应用资源
│   └── data/                  # 数据文件（从 shared_core 同步）
│       ├── ChartConstant.json
│       └── Songlist.json
├── IMAGE_GENERATOR_GUIDE.md   # 图片生成详细指南
├── QUICKSTART_IMAGE_GENERATOR.md  # 图片生成快速开始
├── IMAGE_GENERATOR_MIGRATION.md   # 技术移植文档
### 已实现功能
- [x] 基础 WebView 集成
- [x] shared_core 脚本注入
- [x] 内置设置面板
- [x] 本地设置存储
- [x] 所有核心计算功能
- [x] Android 支持
- [x] iOS 支持
- [x] **B30/R10 图片生成** ✨新
- [x] **自动数据提取** ✨新
- [x] **即时分享功能** ✨新

### 计划功能
- [ ] 应用内更新数据文件
- [ ] 自定义主题色
- [ ] 离线模式（缓存页面）
- [ ] 多账号切换
- [ ] 推分目标跟踪
- [ ] 成绩历史记录
- [ ] 导出成绩报告
- [ ] 图片模板自定义
- [ ] 离线曲绘缓存
### 计划功能
- [ ] 应用内更新数据文件
- [ ] 自定义主题色
- [ ] 离线模式（缓存页面）
- [ ] 多账号切换
- [ ] 推分目标跟踪
- [ ] 成绩历史记录
- [ ] 导出成绩报告

---

## 📄 许可证

本项目仅供学习和个人使用。

**注意事项：**
- Arcaea 是 lowiro 的注册商标
- 定数数据来源于公开资料和社区贡献
- 请勿用于商业用途

---

## 🙏 致谢

- **lowiro** - Arcaea 开发团队
- **Arcaea 中文维基** - 提供谱面定数和曲目数据
- **Flutter 社区** - 优秀的跨平台框架
- **flutter_inappwebview** - 强大的 WebView 插件
- 所有 Arcaea 玩家和贡献者

---

## 🔗 相关链接

- **主项目**: [arcaea-online-helper](../)
- **Chrome 扩展**: [chrome_extension](../chrome_extension/)
- **Arcaea 官网**: https://arcaea.lowiro.com/
- **Arcaea 中文维基**: https://arcwiki.mcd.blue/

---

## 📮 反馈与支持

如有问题、建议或发现 Bug，欢迎通过以下方式反馈：

- 🐛 提交 [GitHub Issues](../../issues)
- 💡 发起 [Pull Request](../../pulls)

---

**享受你的 Arcaea 之旅！** 🎵✨
