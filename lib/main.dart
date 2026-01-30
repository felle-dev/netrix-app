import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const NetworkPrivacyApp());
}

// IP Provider model
class IPProvider {
  final String name;
  final String ipUrl;
  final String detailsUrl; // Can use {ip} placeholder
  final String ipJsonKey;

  IPProvider({
    required this.name,
    required this.ipUrl,
    required this.detailsUrl,
    required this.ipJsonKey,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'ipUrl': ipUrl,
    'detailsUrl': detailsUrl,
    'ipJsonKey': ipJsonKey,
  };

  factory IPProvider.fromJson(Map<String, dynamic> json) => IPProvider(
    name: json['name'],
    ipUrl: json['ipUrl'],
    detailsUrl: json['detailsUrl'],
    ipJsonKey: json['ipJsonKey'],
  );
}

class AppTheme {
  static const String primaryFont = 'Outfit';
  static const String displayFont = 'NoyhR';

  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(fontFamily: displayFont),
      displayMedium: TextStyle(fontFamily: displayFont),
      displaySmall: TextStyle(fontFamily: displayFont),
      headlineLarge: TextStyle(fontFamily: displayFont),
      headlineMedium: TextStyle(fontFamily: displayFont),
      headlineSmall: TextStyle(fontFamily: displayFont),
      titleLarge: TextStyle(fontFamily: displayFont),
    );
  }

  static ThemeData lightTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: primaryFont,
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ThemeData darkTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: primaryFont,
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ColorScheme getDefaultLightColorScheme() {
    return ColorScheme.fromSeed(seedColor: Colors.purple);
  }

  static ColorScheme getDefaultDarkColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: Colors.purple,
      brightness: Brightness.dark,
    );
  }
}

class NetworkPrivacyApp extends StatelessWidget {
  const NetworkPrivacyApp({Key? key}) : super(key: key);

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
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _navIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _currentTitle {
    switch (_navIndex) {
      case 0:
        return 'Privacy';
      case 1:
        return 'App Tracker';
      case 2:
        return 'Speed Test';
      default:
        return 'Netrix';
    }
  }

  void _onPageChanged(int index) {
    setState(() => _navIndex = index);
  }

  void _onNavTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
          children: const [
            NetworkCheckerTab(),
            AppTrackerTab(),
            SpeedTestTab(),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: CustomFloatingNavBar(
        currentIndex: _navIndex,
        onTap: _onNavTapped,
      ),
    );
  }
}

// Network Checker Tab
class NetworkCheckerTab extends StatefulWidget {
  const NetworkCheckerTab({Key? key}) : super(key: key);

  @override
  State<NetworkCheckerTab> createState() => _NetworkCheckerTabState();
}

class _NetworkCheckerTabState extends State<NetworkCheckerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = false;
  Map<String, dynamic>? _networkInfo;
  String? _errorMessage;
  int _currentProviderIndex = 0;
  List<IPProvider> _customProviders = [];

  // Multiple free IP checker providers
  final List<IPProvider> _defaultProviders = [
    IPProvider(
      name: 'ipify',
      ipUrl: 'https://api.ipify.org?format=json',
      detailsUrl: 'https://ipapi.co/{ip}/json/',
      ipJsonKey: 'ip',
    ),
    IPProvider(
      name: 'ipapi',
      ipUrl: 'https://ipapi.co/json/',
      detailsUrl: '',
      ipJsonKey: 'ip',
    ),
    IPProvider(
      name: 'ip-api',
      ipUrl: 'http://ip-api.com/json/',
      detailsUrl: '',
      ipJsonKey: 'query',
    ),
    IPProvider(
      name: 'seeip',
      ipUrl: 'https://api.seeip.org/jsonip',
      detailsUrl: 'https://ipapi.co/{ip}/json/',
      ipJsonKey: 'ip',
    ),
    IPProvider(
      name: 'myip',
      ipUrl: 'https://api.myip.com',
      detailsUrl: 'https://ipapi.co/{ip}/json/',
      ipJsonKey: 'ip',
    ),
    IPProvider(
      name: 'ipgeolocation',
      ipUrl: 'https://api.ipgeolocation.io/getip',
      detailsUrl: 'https://ipapi.co/{ip}/json/',
      ipJsonKey: 'ip',
    ),
    IPProvider(
      name: 'ifconfig',
      ipUrl: 'https://ifconfig.me/all.json',
      detailsUrl: 'https://ipapi.co/{ip}/json/',
      ipJsonKey: 'ip_addr',
    ),
  ];

  List<IPProvider> get _allProviders => [
    ..._defaultProviders,
    ..._customProviders,
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('network_info');
    final customProvidersJson = prefs.getString('custom_providers');

    if (customProvidersJson != null) {
      final List<dynamic> decoded = json.decode(customProvidersJson);
      setState(() {
        _customProviders = decoded.map((e) => IPProvider.fromJson(e)).toList();
      });
    }

    if (cachedData != null) {
      setState(() {
        _networkInfo = json.decode(cachedData);
        _isLoading = false;
      });
    } else {
      _checkNetwork();
    }
  }

  Future<void> _saveCachedData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('network_info', json.encode(data));
  }

  Future<void> _saveCustomProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
      _customProviders.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('custom_providers', encoded);
  }

  Future<void> _checkNetwork() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final info = await _gatherNetworkInfo();
      await _saveCachedData(info);
      setState(() {
        _networkInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error gathering network info: $e';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _gatherNetworkInfo() async {
    final info = <String, dynamic>{};

    // Get local network interfaces
    try {
      final interfaces = await NetworkInterface.list();
      final localAddresses = <Map<String, String>>[];

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          localAddresses.add({
            'interface': interface.name,
            'address': addr.address,
            'type': addr.type.name,
            'isLoopback': addr.isLoopback.toString(),
            'isLinkLocal': addr.isLinkLocal.toString(),
          });
        }
      }
      info['localAddresses'] = localAddresses;
    } catch (e) {
      info['localAddresses'] = 'Error: $e';
    }

    // Get public IP information with fallback providers
    String? publicIP;
    for (int i = 0; i < _allProviders.length; i++) {
      try {
        final provider =
            _allProviders[(_currentProviderIndex + i) % _allProviders.length];
        final response = await http
            .get(Uri.parse(provider.ipUrl))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          publicIP = data[provider.ipJsonKey];

          if (publicIP != null) {
            info['publicIP'] = publicIP;
            info['provider'] = provider.name;
            _currentProviderIndex =
                (_currentProviderIndex + i) % _allProviders.length;

            // Get detailed IP information
            await _getIPDetails(publicIP, info, provider);
            break;
          }
        }
      } catch (e) {
        // Continue to next provider
        continue;
      }
    }

    if (publicIP == null) {
      info['publicIP'] = 'Unable to fetch from any provider';
    }

    // Check DNS leak
    info['dnsServers'] = await _checkDNS();

    // Privacy assessment
    info['privacyAssessment'] = _assessPrivacy(info);

    return info;
  }

  Future<void> _getIPDetails(
    String ip,
    Map<String, dynamic> info,
    IPProvider provider,
  ) async {
    try {
      String detailsUrl = provider.detailsUrl;

      // If provider already has details in the same response
      if (detailsUrl.isEmpty && provider.name == 'ipapi') {
        final response = await http
            .get(Uri.parse(provider.ipUrl))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          await _parseIPDetails(ip, data, info);
          return;
        }
      } else if (detailsUrl.isEmpty && provider.name == 'ip-api') {
        final response = await http
            .get(Uri.parse(provider.ipUrl))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          await _parseIPApiDetails(ip, data, info);
          return;
        }
      }

      // Use separate details URL
      if (detailsUrl.isNotEmpty) {
        detailsUrl = detailsUrl.replaceAll('{ip}', ip);
        final response = await http
            .get(Uri.parse(detailsUrl))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          await _parseIPDetails(ip, data, info);
        }
      }
    } catch (e) {
      info['ipDetails'] = 'Unable to fetch details: $e';
    }
  }

  Future<void> _parseIPDetails(
    String ip,
    Map<String, dynamic> data,
    Map<String, dynamic> info,
  ) async {
    bool isTor = data['org']?.toLowerCase().contains('tor') ?? false;

    try {
      final torCheckResponse = await http
          .get(Uri.parse('https://check.torproject.org/api/ip'))
          .timeout(const Duration(seconds: 5));

      if (torCheckResponse.statusCode == 200) {
        final torData = json.decode(torCheckResponse.body);
        isTor = torData['IsTor'] ?? isTor;
      }
    } catch (e) {
      // If Tor check fails, use previous value
    }

    info['ipDetails'] = {
      'ip': ip,
      'country': data['country_name'] ?? data['country'] ?? 'Unknown',
      'region': data['region'] ?? 'Unknown',
      'city': data['city'] ?? 'Unknown',
      'isp': data['org'] ?? data['isp'] ?? 'Unknown',
      'timezone': data['timezone'] ?? 'Unknown',
      'isTor': isTor,
    };
  }

  Future<void> _parseIPApiDetails(
    String ip,
    Map<String, dynamic> data,
    Map<String, dynamic> info,
  ) async {
    bool isTor = data['org']?.toLowerCase().contains('tor') ?? false;

    try {
      final torCheckResponse = await http
          .get(Uri.parse('https://check.torproject.org/api/ip'))
          .timeout(const Duration(seconds: 5));

      if (torCheckResponse.statusCode == 200) {
        final torData = json.decode(torCheckResponse.body);
        isTor = torData['IsTor'] ?? isTor;
      }
    } catch (e) {
      // If Tor check fails, use previous value
    }

    info['ipDetails'] = {
      'ip': ip,
      'country': data['country'] ?? 'Unknown',
      'region': data['regionName'] ?? 'Unknown',
      'city': data['city'] ?? 'Unknown',
      'isp': data['isp'] ?? 'Unknown',
      'timezone': data['timezone'] ?? 'Unknown',
      'isTor': isTor,
    };
  }

  Future<List<String>> _checkDNS() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.map((addr) => addr.address).toList();
    } catch (e) {
      return ['Unable to check DNS'];
    }
  }

  Map<String, dynamic> _assessPrivacy(Map<String, dynamic> info) {
    final assessment = <String, dynamic>{};
    final warnings = <String>[];
    final tips = <String>[];

    bool isTor = false;
    if (info['ipDetails'] is Map) {
      isTor = info['ipDetails']['isTor'] ?? false;
      final isp = info['ipDetails']['isp']?.toString().toLowerCase() ?? '';
      final isVPN =
          isp.contains('vpn') ||
          isp.contains('proxy') ||
          isp.contains('cloudflare') ||
          isp.contains('datacenter');

      assessment['usingVPN'] = isVPN;
      assessment['usingTor'] = isTor;

      if (!isVPN && !isTor) {
        warnings.add('You may not be using a VPN or Tor');
        tips.add('Consider using a VPN or Tor for enhanced privacy');
      }
    }

    if (info['localAddresses'] is List) {
      final hasIPv6 = (info['localAddresses'] as List).any(
        (addr) => addr['type'] == 'IPv6' && addr['isLinkLocal'] == 'false',
      );

      if (hasIPv6 && !isTor) {
        warnings.add('IPv6 addresses detected - potential privacy leak');
        tips.add('Disable IPv6 or ensure your VPN supports it');
      }
    }

    assessment['warnings'] = warnings;
    assessment['tips'] = tips;
    assessment['privacyScore'] = _calculatePrivacyScore(warnings, isTor);

    return assessment;
  }

  int _calculatePrivacyScore(List<String> warnings, bool isTor) {
    int baseScore = 100;
    if (isTor) {
      baseScore = 100;
    } else {
      baseScore = (100 - (warnings.length * 20)).clamp(0, 100);
    }
    return baseScore;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showProviderSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProviderSettingsSheet(
        customProviders: _customProviders,
        defaultProviders: _defaultProviders,
        onAddProvider: (provider) {
          setState(() {
            _customProviders.add(provider);
          });
          _saveCustomProviders();
        },
        onDeleteProvider: (index) {
          setState(() {
            _customProviders.removeAt(index);
          });
          _saveCustomProviders();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _checkNetwork,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_networkInfo == null) {
      return const Center(child: Text('No network information available'));
    }

    return RefreshIndicator(
      onRefresh: _checkNetwork,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildPrivacyScore(),
          const SizedBox(height: 16),
          _buildPublicIPCard(),
          const SizedBox(height: 16),
          _buildIPDetailsCard(),
          const SizedBox(height: 16),
          _buildLocalAddressesCard(),
          const SizedBox(height: 16),
          _buildPrivacyTipsCard(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _checkNetwork,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showProviderSettingsDialog,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Providers'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPrivacyScore() {
    final theme = Theme.of(context);
    final assessment =
        _networkInfo?['privacyAssessment'] as Map<String, dynamic>?;
    final score = assessment?['privacyScore'] ?? 0;
    final usingVPN = assessment?['usingVPN'] ?? false;
    final usingTor = assessment?['usingTor'] ?? false;
    final provider = _networkInfo?['provider'] ?? 'Unknown';

    Color scoreColor;
    String scoreLabel;

    if (score >= 80) {
      scoreColor = Colors.green;
      scoreLabel = 'Good';
    } else if (score >= 50) {
      scoreColor = Colors.orange;
      scoreLabel = 'Fair';
    } else {
      scoreColor = Colors.red;
      scoreLabel = 'Poor';
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Privacy Score',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    provider,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 12,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '$score',
                          style: theme.textTheme.displayLarge?.copyWith(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          scoreLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scoreColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: usingTor
                        ? Colors.purple.withOpacity(0.1)
                        : usingVPN
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        usingTor
                            ? Icons.vpn_lock_rounded
                            : usingVPN
                            ? Icons.shield_rounded
                            : Icons.shield_outlined,
                        color: usingTor
                            ? Colors.purple
                            : usingVPN
                            ? Colors.green
                            : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        usingTor
                            ? 'Tor Network Detected'
                            : usingVPN
                            ? 'VPN Detected'
                            : 'No VPN/Tor Detected',
                        style: TextStyle(
                          color: usingTor
                              ? Colors.purple
                              : usingVPN
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicIPCard() {
    final theme = Theme.of(context);
    final publicIP = _networkInfo?['publicIP'] ?? 'Unknown';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.public_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Public IP Address',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      publicIP,
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => _copyToClipboard(publicIP),
                    tooltip: 'Copy to clipboard',
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIPDetailsCard() {
    final theme = Theme.of(context);
    final details = _networkInfo?['ipDetails'];

    if (details is! Map) {
      return const SizedBox.shrink();
    }

    final isTor = details['isTor'] == true;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  isTor ? Icons.vpn_lock_rounded : Icons.location_on_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isTor ? 'Tor Exit Node Details' : 'IP Location Details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          if (isTor) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.vpn_lock_rounded, color: Colors.purple, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Tor Network Active',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your real location is hidden. Only the Tor exit node IP is visible.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            if (details['country'] != 'Unknown')
              _buildDetailListTile(
                'Exit Node Country',
                details['country'],
                theme,
              ),
            if (details['country'] != 'Unknown' &&
                details['region'] != 'Unknown')
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
            if (details['region'] != 'Unknown')
              _buildDetailListTile(
                'Exit Node Region',
                details['region'],
                theme,
              ),
            if (details['region'] != 'Unknown' && details['city'] != 'Unknown')
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
            if (details['city'] != 'Unknown')
              _buildDetailListTile('Exit Node City', details['city'], theme),
            if (details['city'] != 'Unknown' && details['isp'] != 'Unknown')
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
            if (details['isp'] != 'Unknown')
              _buildDetailListTile('Exit Node ISP', details['isp'], theme),
          ] else ...[
            if (details['country'] != 'Unknown')
              _buildDetailListTile('Country', details['country'], theme),
            if (details['country'] != 'Unknown' &&
                details['region'] != 'Unknown')
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
            if (details['region'] != 'Unknown')
              _buildDetailListTile('Region', details['region'], theme),
            if (details['region'] != 'Unknown' && details['city'] != 'Unknown')
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
            if (details['city'] != 'Unknown')
              _buildDetailListTile('City', details['city'], theme),
            if (details['city'] != 'Unknown' && details['isp'] != 'Unknown')
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
            if (details['isp'] != 'Unknown')
              _buildDetailListTile('ISP', details['isp'], theme),
            if (details['isp'] != 'Unknown' && details['timezone'] != 'Unknown')
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
            if (details['timezone'] != 'Unknown')
              _buildDetailListTile('Timezone', details['timezone'], theme),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailListTile(String label, String? value, ThemeData theme) {
    return ListTile(
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          value ?? 'Unknown',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLocalAddressesCard() {
    final theme = Theme.of(context);
    final addresses = _networkInfo?['localAddresses'];

    if (addresses is! List || addresses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.devices_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Local Network Addresses',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: addresses
                  .map<Widget>(
                    (addr) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${addr['interface']} (${addr['type']})',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            addr['address'],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTipsCard() {
    final theme = Theme.of(context);
    final assessment =
        _networkInfo?['privacyAssessment'] as Map<String, dynamic>?;
    final warnings = assessment?['warnings'] as List? ?? [];
    final tips = assessment?['tips'] as List? ?? [];

    if (warnings.isEmpty && tips.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Your network privacy looks good!',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Privacy Recommendations',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (warnings.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Warnings',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...warnings.map(
                          (warning) => Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(color: Colors.orange[700]),
                                ),
                                Expanded(
                                  child: Text(
                                    warning,
                                    style: TextStyle(color: Colors.orange[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (tips.isNotEmpty) ...[
                  if (warnings.isNotEmpty) const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tips',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...tips.map(
                          (tip) => Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    tip,
                                    style: TextStyle(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Provider Settings Sheet
class _ProviderSettingsSheet extends StatefulWidget {
  final List<IPProvider> customProviders;
  final List<IPProvider> defaultProviders;
  final Function(IPProvider) onAddProvider;
  final Function(int) onDeleteProvider;

  const _ProviderSettingsSheet({
    required this.customProviders,
    required this.defaultProviders,
    required this.onAddProvider,
    required this.onDeleteProvider,
  });

  @override
  State<_ProviderSettingsSheet> createState() => _ProviderSettingsSheetState();
}

class _ProviderSettingsSheetState extends State<_ProviderSettingsSheet> {
  final _nameController = TextEditingController();
  final _ipUrlController = TextEditingController();
  final _detailsUrlController = TextEditingController();
  final _jsonKeyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _ipUrlController.dispose();
    _detailsUrlController.dispose();
    _jsonKeyController.dispose();
    super.dispose();
  }

  void _showAddProviderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Provider'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Provider Name',
                  hintText: 'e.g., MyIPService',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ipUrlController,
                decoration: const InputDecoration(
                  labelText: 'IP URL',
                  hintText: 'https://api.example.com/ip',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _jsonKeyController,
                decoration: const InputDecoration(
                  labelText: 'IP JSON Key',
                  hintText: 'ip',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsUrlController,
                decoration: const InputDecoration(
                  labelText: 'Details URL (optional)',
                  hintText: 'Use {ip} as placeholder',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty &&
                  _ipUrlController.text.isNotEmpty &&
                  _jsonKeyController.text.isNotEmpty) {
                widget.onAddProvider(
                  IPProvider(
                    name: _nameController.text,
                    ipUrl: _ipUrlController.text,
                    detailsUrl: _detailsUrlController.text,
                    ipJsonKey: _jsonKeyController.text,
                  ),
                );
                _nameController.clear();
                _ipUrlController.clear();
                _detailsUrlController.clear();
                _jsonKeyController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'IP Provider Settings',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Default Providers',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...widget.defaultProviders.map(
                (provider) => ListTile(
                  leading: Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(provider.name),
                  subtitle: Text(provider.ipUrl),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Custom Providers',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _showAddProviderDialog,
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add Provider',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.customProviders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No custom providers added',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ...widget.customProviders.asMap().entries.map(
                  (entry) => ListTile(
                    leading: Icon(
                      Icons.cloud_outlined,
                      color: theme.colorScheme.secondary,
                    ),
                    title: Text(entry.value.name),
                    subtitle: Text(entry.value.ipUrl),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () => widget.onDeleteProvider(entry.key),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// App Tracker Tab (Placeholder)
class AppTrackerTab extends StatelessWidget {
  const AppTrackerTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.radar_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Internet Access Monitor',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.apps_outlined,
                      size: 80,
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'App Internet Tracker',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Track which apps are accessing the internet and monitor their network activity in real-time.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(
                          0.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Coming Soon',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.featured_play_list_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Planned Features',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ListTile(
                leading: Icon(
                  Icons.phone_android_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Per-App Data Usage'),
                subtitle: const Text('Monitor data consumption by app'),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
              ListTile(
                leading: Icon(
                  Icons.block_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Internet Access Control'),
                subtitle: const Text('Block apps from accessing internet'),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
              ListTile(
                leading: Icon(
                  Icons.analytics_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Real-time Monitoring'),
                subtitle: const Text('See active connections in real-time'),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
              ListTile(
                leading: Icon(
                  Icons.history_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Usage History'),
                subtitle: const Text('Track historical data patterns'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}

// Speed Test Tab (Placeholder)
class SpeedTestTab extends StatelessWidget {
  const SpeedTestTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.speed_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Internet Speed Test',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          width: 12,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.network_check_outlined,
                              size: 60,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ready',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Speed Test',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Measure your internet connection speed with download, upload, and ping tests.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(
                          0.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Coming Soon',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.list_alt_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Test Features',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ListTile(
                leading: Icon(
                  Icons.download_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Download Speed'),
                subtitle: const Text('Measure download bandwidth'),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
              ListTile(
                leading: Icon(
                  Icons.upload_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Upload Speed'),
                subtitle: const Text('Measure upload bandwidth'),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
              ListTile(
                leading: Icon(
                  Icons.timer_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Ping & Latency'),
                subtitle: const Text('Test connection response time'),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
              ListTile(
                leading: Icon(
                  Icons.storage_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Test History'),
                subtitle: const Text('View past speed test results'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}

// Custom Navigation Bar
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              isSelected ? selectedIcon : icon,
              key: ValueKey(isSelected),
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class CustomFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.shield_outlined,
                  selectedIcon: Icons.shield,
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.radar_outlined,
                  selectedIcon: Icons.radar,
                  isSelected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
                _NavItem(
                  icon: Icons.speed_outlined,
                  selectedIcon: Icons.speed,
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
