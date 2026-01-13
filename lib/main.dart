import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'models/app_settings.dart';
import 'services/image_generation_manager.dart';
import 'widgets/arcaea_webview_page.dart';
import 'widgets/ptt_page.dart';
import 'widgets/score_list_page.dart';

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

  runApp(const ArcaeaHelperApp());
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
  bool _lastLoginState = false;
  bool _showWebView = false;
  late final ImageGenerationManager _imageManager;
  AppSettings _appSettings = AppSettings();

  @override
  void initState() {
    super.initState();
    _imageManager = ImageGenerationManager();
    _imageManager.loadFromCache();
    _loadAppSettings();
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
        : (_currentIndex >= 2 ? 2 : _currentIndex);
    
    final scoreListPage = ScoreListPage(
      imageManager: _imageManager,
      isActive: (_showWebView && displayIndex == 2) || 
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

    final List<Widget> pages = _showWebView
        ? [pttPage, webViewPage, scoreListPage]
        : [pttPage, scoreListPage, webViewPage];
    
    return Scaffold(
      body: IndexedStack(
        index: displayIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    if (_showWebView) {
      return BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'PTT'),
          BottomNavigationBarItem(icon: Icon(Icons.web), label: 'WebView'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '成绩列表'),
        ],
      );
    } else {
      return BottomNavigationBar(
        currentIndex: _currentIndex.clamp(0, 1),
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'PTT'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '成绩列表'),
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
