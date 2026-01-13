# 🎵 Arcaea Helper Mobile

一个基于 Flutter 的跨平台 Arcaea Online 辅助应用，专注于提供完整的成绩管理和数据分析功能。支持 Android 和 iOS 平台。

**目前定数表适用于移动版 v6.11.0。**

---

## ✨ 核心功能

### 📊 PTT 数据展示
采用原生 Flutter 设计，提供流畅稳定的成绩浏览体验：

- 🎯 **谱面定数显示** - 在曲目名称旁显示定数，如 `Tempestissimo (11.3)`
- 💎 **单曲 PTT 计算** - 实时计算并显示每首歌的 Potential 值
- 🎓 **精确总 PTT** - 基于 Best 30 和 Recent 10 计算准确的总 PTT 值
- 🎯 **推分目标提示** - 显示使显示 PTT +0.01 所需的目标分数
- 📈 **定数需求卡片** - 展示达到 +0.01 PTT 所需的最低谱面定数（EX+、EX、995W 等级别）
- 🔢 **序号标识** - 自动为 Best 30 (#1-#30) 和 Recent 10 (R1-R10) 添加序号
- 🖼️ **图片导出** - 一键生成高清 PTT 图片（2400x3900分辨率，PNG格式）
- 📱 **自动保存** - 生成的图片自动保存到相册，可直接分享

### 🔄 后台自动更新（新功能）
应用启动时自动保持数据最新：

- 🚀 **启动时自动更新** - 应用启动后自动检查并更新曲目数据和成绩列表
- 📊 **曲目数据更新** - 自动从 GitHub 获取最新的歌曲定数和曲包信息
- 🎯 **成绩增量更新** - 如果已有缓存成绩，自动拉取新增的成绩记录
- ⏱️ **智能间隔控制** - 默认每 6 小时更新一次，避免频繁请求
- 🔇 **静默更新** - 后台执行，不阻塞应用启动和使用
- 💬 **状态提示** - 更新时在顶部显示进度提示，完成后自动消失

### 📋 全成绩列表管理
全新的成绩列表功能，提供深度数据分析：

- 📥 **全量拉取** - 自动从 Arcaea Online 拉取所有难度的全部成绩
- 🔄 **增量更新** - 支持增量更新模式，只拉取新成绩，节省时间
- 💾 **本地存储** - 成绩数据持久化保存，离线也可查看
- 🔍 **搜索功能** - 支持曲目名称搜索，快速定位
- 🎚️ **多维度筛选**：
  - 按难度筛选（PST/PRS/FTR/ETR/BYD）
  - 按等级筛选（定数范围）
  - 按分数筛选（分数段）
  - 按 PTT 筛选（PTT 范围）
  - 按目标分数筛选（推分候选）
  - 只显示 B30/R10 中的曲目
- 📊 **多种排序方式**：
  - 按日期排序（最新/最早）
  - 按定数排序
  - 按单曲 PTT 排序
  - 按成绩排序
  - **按目标分数排序** - 找出最容易推分的曲目
  - **按目标差值排序** - 显示距离目标最近的成绩
- 🎯 **智能推分建议**：
  - 自动计算每首歌的目标分数（已在 B30/R10 中）
  - 计算替代 B30 最低成绩的目标分数
  - 计算替代 R10 最低成绩的目标分数
  - 显示最优推分路径（B30 或 R10）
- 📈 **可视化展示** - 成绩卡片显示歌曲封面、定数、PTT、目标等完整信息
- 📊 **统计信息** - 显示总成绩数、筛选结果数量、上次更新时间


---

## 🚀 快速开始

### 📱 用户使用

⚠️ **前提条件**：需要已订阅 [Arcaea Online](https://arcaea.lowiro.com/) 服务

#### 基本使用流程

1. **首次使用 - 登录**
   - 打开应用，等待 3 次重试失败后点击进入 Webview 登录后回到 PTT 页

2. **查看 PTT 数据**
   - 点击底部导航栏的「PTT」标签
   - 点击「刷新数据」从 Arcaea Online 获取最新数据
   - 查看详细的成绩卡片、定数、PTT、推分目标

3. **导出 PTT 图片**
   - 在「PTT」页面，点击设置按钮
   - 选择「生成图片」
   - 等待生成完成后，图片会自动保存到相册

4. **分析成绩与推分**
   - 在「成绩列表」中使用筛选功能找出推分候选
   - 按「目标分数」或「目标差值」排序，找出最容易提升的曲目
   - 查看每首歌的目标分数和推荐路径（替代 B30 或 R10）

5. **更新成绩**
   - 在「成绩列表」中点击「增量更新」只拉取新成绩
   - 或点击「拉取」重新拉取全部成绩

### 🛠️ 开发者使用

**环境要求：**
- Flutter SDK >= 3.10.1
- Dart SDK >= 3.10.1
- Android Studio / Xcode（根据目标平台）

**构建发布版本：**

```bash
# Android APK
flutter build apk --release

# Android App Bundle (用于 Google Play)
flutter build appbundle --release

# iOS (需要 Apple Developer 账号)
flutter build ios --release
# 然后在 Xcode 中打开 ios/Runner.xcworkspace 进行签名
```

## 🛠️ 技术架构

### 应用架构

```
lib/
├── main.dart                  # 应用入口，标签页导航
├── core/
│   └── constants.dart         # 全局常量配置
├── models/                    # 数据模型
│   ├── app_settings.dart      # 应用设置
│   ├── b30r10_data.dart       # B30/R10 数据结构
│   ├── score_data.dart        # 成绩数据结构
│   ├── score_filter.dart      # 筛选条件
│   └── score_sort_option.dart # 排序选项
├── services/                  # 业务逻辑层
│   ├── webview_script_manager.dart     # WebView 脚本注入管理
│   ├── image_generation_manager.dart   # 图片生成状态管理
│   ├── image_generator_service.dart    # 图片生成核心服务
│   ├── score_fetch_service.dart        # 成绩拉取服务（使用 HeadlessWebView）
│   ├── score_storage_service.dart      # 成绩本地存储
│   ├── song_data_service.dart          # 歌曲元数据服务
│   ├── data_update_service.dart        # 定数数据更新
│   └── update_service.dart             # 应用版本检查
└── widgets/                   # UI 组件
    ├── ptt_page.dart          # PTT 展示页面
    ├── score_list_page.dart   # 成绩列表页面
    ├── score_filter_dialog.dart # 筛选对话框
    └── settings_dialog.dart   # 设置对话框
```

### 核心依赖

```yaml
dependencies:
  flutter_inappwebview: ^6.0.0    # WebView 组件（页面浏览和数据拉取）
  shared_preferences: ^2.2.2      # 本地设置存储
  path_provider: ^2.1.1           # 文件路径访问
  image: ^4.1.7                   # 图片处理
  http: ^1.2.0                    # HTTP 请求（加载曲绘）
  intl: ^0.19.0                   # 国际化和日期格式化
  gal: ^2.3.0                     # 相册访问（保存图片）
  package_info_plus: ^9.0.0       # 应用版本信息
  url_launcher: ^6.3.0            # 打开外部链接
```

### 数据流程

#### 1. B30/R10 数据获取
```
用户点击刷新
  ↓
WebView 加载 Arcaea Online /profile/potential 页面
  ↓
注入 JavaScript 脚本
  ↓
提取页面中的 B30/R10 数据
  ↓
通过 JavaScript Handler 传回 Flutter
  ↓
解析为 B30R10Data 模型
  ↓
更新 ImageGenerationManager 状态
  ↓
UI 自动刷新显示
```

#### 2. 全成绩拉取
```
用户点击拉取按钮
  ↓
创建 HeadlessInAppWebView（无界面 WebView）
  ↓
依次访问所有难度的成绩列表页面
  ↓
每个页面注入数据提取脚本
  ↓
解析 JSON 数据为 ScoreData 列表
  ↓
保存到本地 SharedPreferences
  ↓
更新 UI 显示
```

#### 3. 图片生成
```
用户点击生成图片
  ↓
ImageGenerationManager 触发
  ↓
ImageGeneratorService 创建画布
  ↓
依次绘制：
  - 背景渐变
  - 玩家信息头部
  - B30 成绩卡片（下载曲绘）
  - R10 成绩卡片
  - 定数需求卡片
  ↓
编码为 PNG
  ↓
保存到临时目录
  ↓
通过 Gal 保存到相册
  ↓
显示完成提示
```

### 推分算法

#### PTT 计算公式

```dart
单曲 PTT = 
  if (score >= 10,000,000)
    constant + 2.0
  else if (score >= 9,800,000)
    constant + 1.0 + (score - 9,800,000) / 200,000.0
  else
    constant + (score - 9,500,000) / 300,000.0

总 PTT = (Best 30 PTT 之和 + Recent 10 PTT 之和) / 40
显示 PTT = floor(总 PTT * 100) / 100
```

#### 目标分数计算

使用二分搜索算法，寻找最小分数 S，使得：

```dart
新总 PTT = 旧总 PTT - 旧单曲 PTT / 40 + 新单曲 PTT(S) / 40
floor(新总 PTT * 100) / 100 >= floor(旧总 PTT * 100) / 100 + 0.01
```

#### 智能推分建议

对于不在 B30/R10 中的成绩，计算两种推分路径：

1. **替代 B30 路径**：计算替代 B30 中最低成绩所需的目标分数
2. **替代 R10 路径**：计算替代 R10 中最低成绩所需的目标分数

选择目标分数更低（更容易达成）的路径显示给用户。

---

## 📊 算法说明

### 成绩筛选逻辑

支持多条件组合筛选：

- **难度筛选**：可选择一个或多个难度
- **定数范围**：最小值 ≤ 定数 ≤ 最大值
- **分数范围**：最小值 ≤ 分数 ≤ 最大值
- **PTT 范围**：最小值 ≤ PTT ≤ 最大值
- **目标分数范围**：最小值 ≤ 目标 ≤ 最大值
- **仅显示有目标**：只显示可推分的成绩
- **仅 B30/R10**：只显示在 B30/R10 中的成绩

### 排序选项

| 排序方式 | 说明 | 适用场景 |
|---------|------|---------|
| 日期降序 | 最新成绩在前 | 查看最近游玩 |
| 日期升序 | 最早成绩在前 | 查看历史成绩 |
| 定数降序 | 定数高的在前 | 挑战高难度 |
| PTT 降序 | PTT 高的在前 | 查看高质量成绩 |
| 成绩降序 | 分数高的在前 | 查看高分 |
| 成绩升序 | 分数低的在前 | 找出可提升的成绩 |
| 目标升序 | 目标分数低的在前 | **推分优先** - 找最容易达成的目标 |
| 目标降序 | 目标分数高的在前 | 查看高难度目标 |
| 目标差值升序 | 距离目标最近的在前 | **推分优先** - 差一点就能达成的 |
| 目标差值降序 | 距离目标最远的在前 | 查看差距大的成绩 |

---

## 🔧 常见问题

### Q: 为什么需要拉取成绩？
A: Arcaea Online 的 B30/R10 页面只显示最佳成绩，不包含所有历史成绩。通过拉取全部成绩，可以进行更深入的分析，例如找出所有可以推分的曲目。

### Q: 增量更新和完整拉取有什么区别？
A: 
- **完整拉取**：重新拉取所有难度的所有成绩，耗时较长但数据最完整
- **增量更新**：只拉取新产生的成绩（通过日期判断），速度快，适合日常更新

### Q: 目标分数是如何计算的？
A: 根据您当前的总 PTT，计算出每首歌需要达到多少分才能使显示 PTT +0.01。对于不在 B30/R10 中的歌，会计算替代 B30 或 R10 最低成绩所需的分数。

### Q: 图片生成失败怎么办？
A: 
1. 确保已授予相册访问权限
2. 确保已成功获取 B30/R10 数据
3. 检查设备存储空间是否充足
4. 尝试重新拉取数据后再生成

### Q: 定数数据如何更新？
A: 在设置对话框中点击「更新定数数据」，应用会从 GitHub 仓库下载最新的 ChartConstant.json 文件。

---

## 📝 更新历史

### v1.2.0
- ⚠️ **升级提醒** - 强烈建议升级后先点击「清除所有数据」再重新登录获取成绩，经测试旧版数据可能存在兼容性问题
- ✨ **搭档系统** - 支持获取搭档信息，提供基础排序及针对"失落陷落"章节的高级排序，助你轻松选出世界模式最佳搭档
- 👥 **好友系统** - 支持获取好友列表及详细信息，可直接查询并分析好友的成绩列表
- 📊 **PTT 扩展显示** - PTT 页面新增 B30-B50 扩展显示功能，数据展示更全面
- 🖼️ **个性化头像** - 支持显示个性化的搭档头像
- 🔄 **自动更新** - 加入启动时自动更新成绩列表与定数表功能，确保数据实时同步
- 🧹 **数据管理** - 新增一键清除所有数据功能，方便重置应用状态
- 🔐 **登录入口优化** - 在设置页新增登录入口，方便快捷地进行账号登录
- 🎨 **UI 优化** - 调整并优化了部分页面 UI 显示，提升视觉体验
- 🐛 **问题修复**：
  - 修复启动时 PTT 信息可能刷新失败的问题
  - 修复不同日期格式导致的成绩列表排序错乱问题
  - 修复成绩列表页目标分数可能同步异常的问题
  - 修复获取成绩时 ETR 和 BYD 难度识别异常的问题
  - 修复其他已知 Bug，显著提升应用稳定性

### v1.1.2
- 🐛 **问题修复** - 修复我也不知道是什么反正某首曲目某种情况不能正常显示的问题

### v1.1.1
- 🐛 **问题修复** - 修复冷启动时有较大概率不能加载玩家信息的问题
- ⚡ **性能优化** - 优化成绩获取与更新速度与显示
- ✨ **新功能** - 新增更新成绩时选择特定难度功能
- 🐛 **问题修复** - 修复成绩列表可能不能正常显示目标的问题

### v1.1.0 
- 🎨 **PTT页面重构** - 改为原生Flutter样式，提高稳定性和性能
- 📊 **曲目列表功能** - 新增曲目列表功能，支持拉取全部成绩并进行详细全面的分析
- 🚫 **Chrome扩展维护终止** - 专注于移动端开发，不再维护Chrome扩展
- 🐛 **问题修复** - 修复已知问题，提升整体稳定性

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

---

## 📄 许可证

本项目采用 MIT 许可证。详见 LICENSE 文件。

---

## 🙏 致谢

- [Arcaea](https://arcaea.lowiro.com/) - lowiro 开发的音乐游戏
- [Flutter](https://flutter.dev/) - 跨平台应用开发框架
- 社区贡献的谱面定数数据

---

## ⚠️ 免责声明

本应用为第三方非官方工具，与 lowiro 或 Arcaea 官方无关。使用本应用产生的任何问题，开发者概不负责。请遵守 Arcaea Online 的使用条款。
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
