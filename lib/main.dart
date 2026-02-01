import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'tabs/network_checker_tab.dart';
import 'theme/app_theme.dart';
import 'services/home_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          // Add unique key to force rebuild when theme changes
          builder: (context, child) {
            // This ensures proper theme transitions
            return child ?? const SizedBox.shrink();
          },
          onGenerateRoute: (settings) {
            final uri = Uri.tryParse(settings.name ?? '');
            final isRefresh = uri?.host == 'refresh' || 
                              settings.name == '/refresh' ||
                              settings.name?.contains('refresh') == true;
            
            return MaterialPageRoute(
              builder: (context) => HomeScreen(autoRefresh: isRefresh),
            );
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey<NetworkCheckerTabState> _networkCheckerKey = GlobalKey();
  bool _isInitialized = false;
  
  // Track the last brightness to detect changes
  Brightness? _lastBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastBrightness = Theme.of(context).brightness;
      _initializeServices();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    // Force rebuild when platform brightness changes
    if (mounted) {
      setState(() {
        // This will trigger a rebuild with the new theme
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app resumes, check if theme changed while app was in background
    if (state == AppLifecycleState.resumed && mounted) {
      final currentBrightness = MediaQuery.of(context).platformBrightness;
      if (_lastBrightness != currentBrightness) {
        print('Theme changed while app was paused, forcing rebuild');
        setState(() {
          _lastBrightness = currentBrightness;
        });
      }
    }
  }

  Future<void> _initializeServices() async {
    if (_isInitialized) return;
    
    try {
      final widgetService = HomeWidgetService();
      await widgetService.initialize();
      
      if (widget.autoRefresh) {
        print('Auto-refresh triggered from widget');
        await Future.delayed(const Duration(milliseconds: 500));
        await _networkCheckerKey.currentState?.refreshNetwork();
      }
      
      _isInitialized = true;
    } catch (e) {
      print('Error initializing services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Update last brightness
    _lastBrightness = theme.brightness;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      // CRITICAL: Use a unique key based on theme to force rebuild
      key: ValueKey('home_${theme.brightness}'),
      body: NestedScrollView(
        // CRITICAL: Also give NestedScrollView a key
        key: ValueKey('nested_${theme.brightness}'),
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
              flexibleSpace: FlexibleSpaceBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      'Network Matrix',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              ),
            ),
          ];
        },
        body: NetworkCheckerTab(key: _networkCheckerKey),
      ),
    );
  }
}
