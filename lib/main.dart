import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:dynamic_color/dynamic_color.dart';
import 'tabs/network_checker_tab.dart';
import 'theme/app_theme.dart';
import 'services/home_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize home widget
  final widgetService = HomeWidgetService();
  await widgetService.initialize();

  // Register background callback for widget updates
  await HomeWidgetService.registerBackgroundCallback();

  // Update widget on app start
  await widgetService.updateWidget();

  runApp(const NetrixApp());
}

class NetrixApp extends StatelessWidget {
  const NetrixApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          lightColorScheme = AppTheme.getDefaultLightColorScheme();
          darkColorScheme = AppTheme.getDefaultDarkColorScheme();
        }

        return MaterialApp(
          title: 'Netrix',
          theme: AppTheme.lightTheme(lightColorScheme),
          darkTheme: AppTheme.darkTheme(darkColorScheme),
          themeMode: ThemeMode.system,
          debugShowCheckedModeBanner: false,
          // Handle deep links from widget refresh button
          onGenerateRoute: (settings) {
            if (settings.name == '/refresh' ||
                settings.name?.contains('refresh') == true) {
              // Widget refresh button was tapped - open app and refresh
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(autoRefresh: true),
              );
            }
            return MaterialPageRoute(builder: (context) => const HomeScreen());
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool autoRefresh;

  const HomeScreen({Key? key, this.autoRefresh = false}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  late PageController _pageController;
  final GlobalKey<NetworkCheckerTabState> _networkCheckerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _navIndex);

    // If opened from widget refresh, trigger a refresh after build
    if (widget.autoRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _networkCheckerKey.currentState?.refreshNetwork();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _currentTitle {
    switch (_navIndex) {
      case 0:
        return 'Network Matrix';
      default:
        return 'Network Matrix';
    }
  }

  void _onPageChanged(int index) {
    setState(() => _navIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentTitle == "Network Matrix") ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'NETRIX',
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else ...[
                      Text(
                        _currentTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              ),
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
            ),
          ];
        },
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: [
            NetworkCheckerTab(key: _networkCheckerKey),
            // AppTrackerTab(),
            // SpeedTestTab(),
          ],
        ),
      ),
      extendBody: true,
      // bottomNavigationBar: CustomFloatingNavBar(
      //   currentIndex: _navIndex,
      //   onTap: _onNavTapped,
      // ),
    );
  }
}
