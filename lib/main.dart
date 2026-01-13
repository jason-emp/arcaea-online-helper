import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'models/app_settings.dart';
import 'services/background_update_service.dart';
import 'services/image_generation_manager.dart';
import 'widgets/arcaea_webview_page.dart';
import 'widgets/ptt_page.dart';
import 'widgets/score_list_page.dart';
import 'widgets/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 仅在Android平台启用WebView调试
  if (defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  // 捕获全局错误
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      debugPrint('Flutter错误: ${details.exception}');
      debugPrint('堆栈: ${details.stack}');
    }
  };

  // 启动后台自动更新服务
  _initBackgroundUpdate();

  runApp(const ArcaeaHelperApp());
}

/// 初始化后台自动更新
void _initBackgroundUpdate() {
  final updateService = BackgroundUpdateService();

  // 在后台异步执行更新，不阻塞应用启动
  Future.delayed(const Duration(seconds: 2), () async {
    if (kDebugMode) {
      debugPrint('启动后台自动更新...');
    }

    try {
      // 强制更新，忽略时间间隔检查
      await updateService.performAutoUpdate(forceUpdate: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('后台自动更新失败: $e');
      }
    }
  });
}

/// Arcaea Helper 应用入口
class ArcaeaHelperApp extends StatelessWidget {
  const ArcaeaHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcaea Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667EEA),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Fira Sans',
      ),
      home: const MainTabPage(),
    );
  }
}

/// 主页面（底部导航）
class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _currentIndex = 0;
  final GlobalKey<ArcaeaWebViewPageState> _webViewKey = GlobalKey();
  final GlobalKey<State<ScoreListPage>> _scoreListKey = GlobalKey();
  bool _lastLoginState = false;
  bool _showWebView = false;
  late final ImageGenerationManager _imageManager;
  late final BackgroundUpdateService _backgroundUpdateService;
  AppSettings _appSettings = AppSettings();
  String? _updateStatusMessage;
  StreamSubscription? _updateStatusSubscription;

  @override
  void initState() {
    super.initState();
    _imageManager = ImageGenerationManager();
    _imageManager.loadFromCache();
    _loadAppSettings();
    _initBackgroundUpdateListener();
  }

  /// 初始化后台更新监听
  void _initBackgroundUpdateListener() {
    _backgroundUpdateService = BackgroundUpdateService();

    // 监听更新状态
    _updateStatusSubscription = _backgroundUpdateService.updateStatusStream
        .listen((status) {
          if (mounted) {
            setState(() {
              _updateStatusMessage = status;
            });

            // 如果更新完成，刷新成绩列表并清除消息
            if (status.contains('完成') || status.contains('失败')) {
              // 如果是成功完成且包含成绩更新，刷新成绩列表
              if (status.contains('后台更新完成') || status.contains('成绩列表更新完成')) {
                final scoreListState = _scoreListKey.currentState;
                if (scoreListState != null) {
                  try {
                    (scoreListState as dynamic).refreshScores();
                  } catch (e) {
                    if (kDebugMode) {
                      debugPrint('刷新成绩列表失败: $e');
                    }
                  }
                }
              }

              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _updateStatusMessage = null;
                  });
                }
              });
            }
          }
        });
  }

  Future<void> _loadAppSettings() async {
    final settings = await AppSettings.load();
    if (mounted) {
      setState(() => _appSettings = settings);
    } else {
      _appSettings = settings;
    }
  }

  void _navigateToWebView() {
    setState(() {
      _showWebView = true;
      _currentIndex = 1;
    });
  }

  void _refreshData() {
    _webViewKey.currentState?.fetchB30R10Data();
  }

  void _refreshWebView() {
    _webViewKey.currentState?.webViewController?.reload();
  }

  Future<void> _generateImage() async {
    final webViewState = _webViewKey.currentState;
    if (webViewState == null) return;

    if (mounted) setState(() {});

    Timer? updateTimer;
    if (_imageManager.isGenerating) {
      updateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (mounted && _imageManager.isGenerating) {
          setState(() {});
        } else {
          timer.cancel();
        }
      });
    }

    await webViewState.generateImage();
    updateTimer?.cancel();

    if (mounted) setState(() {});
  }

  Future<void> _checkUpdate() async {
    await _webViewKey.currentState?.checkForUpdate();
    if (mounted) setState(() {});
  }

  Future<void> _updateData() async {
    await _webViewKey.currentState?.updateData();
    if (mounted) setState(() {});
  }

  Future<void> _clearAllData() async {
    await _webViewKey.currentState?.clearAllData();
    if (mounted) setState(() {});
  }

  Future<void> _handleSettingsChanged(AppSettings newSettings) async {
    setState(() => _appSettings = newSettings);
    try {
      await newSettings.save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存设置失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _launchLatestRelease() {
    _webViewKey.currentState?.launchLatestRelease();
  }

  @override
  void dispose() {
    _updateStatusSubscription?.cancel();
    _backgroundUpdateService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webViewState = _webViewKey.currentState;
    final isLoggedIn = webViewState?.scriptManager.state.isTargetPage ?? false;

    // 检测登录状态变化
    if (isLoggedIn != _lastLoginState) {
      _lastLoginState = isLoggedIn;
      if (isLoggedIn) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _showWebView = false;
              _currentIndex = 0;
            });
          }
        });
      }
    }

    final int displayIndex = _showWebView
        ? _currentIndex
        : (_currentIndex >= 3 ? 3 : _currentIndex);

    final scoreListPage = ScoreListPage(
      key: _scoreListKey,
      imageManager: _imageManager,
      isActive:
          (_showWebView && displayIndex == 2) ||
          (!_showWebView && displayIndex == 1),
    );

    final pttPage = PTTPage(
      imageManager: _imageManager,
      isLoggedIn: isLoggedIn,
      onNavigateToWebView: _navigateToWebView,
      onRefreshData: _refreshData,
      onRefreshWebView: _refreshWebView,
      onGenerateImage: _generateImage,
      onDownloadLatest: _launchLatestRelease,
      onCheckUpdate: _checkUpdate,
      onUpdateData: _updateData,
      onClearAllData: _clearAllData,
      isCheckingUpdate: webViewState?.isCheckingUpdate ?? false,
      isGeneratingImage: _imageManager.isGenerating,
      isUpdatingData: webViewState?.isUpdatingData ?? false,
      currentVersion: webViewState?.currentVersion,
      latestVersion: webViewState?.latestAvailableVersion,
      updateStatusMessage: webViewState?.updateStatusMessage,
      dataUpdateMessage: webViewState?.dataUpdateMessage,
      lastDataUpdateTime: webViewState?.lastDataUpdateTime,
      settings: _appSettings,
      onSettingsChanged: _handleSettingsChanged,
    );

    final webViewPage = ArcaeaWebViewPage(
      key: _webViewKey,
      imageManager: _imageManager,
      settings: _appSettings,
      onSettingsChanged: _handleSettingsChanged,
    );

    final settingsPage = SettingsPage(
      onGenerateImage: _generateImage,
      onDownloadLatest: _launchLatestRelease,
      onCheckUpdate: _checkUpdate,
      onUpdateData: _updateData,
      onClearAllData: _clearAllData,
      isCheckingUpdate: webViewState?.isCheckingUpdate ?? false,
      isGeneratingImage: _imageManager.isGenerating,
      isUpdatingData: webViewState?.isUpdatingData ?? false,
      canGenerateImage: isLoggedIn,
      currentVersion: webViewState?.currentVersion,
      latestVersion: webViewState?.latestAvailableVersion,
      updateStatusMessage: webViewState?.updateStatusMessage,
      dataUpdateMessage: webViewState?.dataUpdateMessage,
      lastDataUpdateTime: webViewState?.lastDataUpdateTime,
      settings: _appSettings,
      onSettingsChanged: _handleSettingsChanged,
    );

    final List<Widget> pages = _showWebView
        ? [pttPage, webViewPage, scoreListPage, settingsPage]
        : [pttPage, scoreListPage, settingsPage, webViewPage];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: displayIndex, children: pages),
          // 后台更新状态提示
          if (_updateStatusMessage != null &&
              _backgroundUpdateService.isUpdating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _updateStatusMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    if (_showWebView) {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'PTT'),
          BottomNavigationBarItem(icon: Icon(Icons.web), label: 'WebView'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '成绩列表'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      );
    } else {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex.clamp(0, 2),
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'PTT'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '成绩列表'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      );
    }
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() {});
      });
    }
  }
}
