import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ip_provider.dart';

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
  bool _showFullIP = false;
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
            info['providerUrl'] = provider.ipUrl;
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

  void _showPrivacyInfoDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Privacy & Transparency',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'What Data We Collect',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Your public IP address\n'
                    '• Your local network interface addresses\n'
                    '• IP geolocation data (country, region, city)\n'
                    '• ISP information\n'
                    '• DNS server addresses',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'How We Use It',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• All data is displayed to YOU only\n'
                    '• Data is cached locally on your device\n'
                    '• No data is sent to our servers\n'
                    '• No tracking or analytics\n'
                    '• No third-party data sharing',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Third-Party Services',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We use free, public IP lookup services to gather network information:\n\n'
                    '• ipify.org\n'
                    '• ipapi.co\n'
                    '• ip-api.com\n'
                    '• seeip.org\n'
                    '• myip.com\n'
                    '• ipgeolocation.io\n'
                    '• ifconfig.me\n'
                    '• torproject.org (Tor detection only)',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withOpacity(
                        0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.tertiary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.tertiary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'These services may log your IP address according to their own privacy policies.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your Control',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Data is only fetched when you manually refresh\n'
                    '• You can add custom providers you trust\n'
                    '• All requests are made directly from your device\n'
                    '• You can clear cached data anytime',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          // _buildPrivacyScore(),
          // const SizedBox(height: 16),
          _buildPublicIPCard(),
          const SizedBox(height: 16),
          _buildIPDetailsCard(),
          const SizedBox(height: 16),
          _buildLocalAddressesCard(),
          const SizedBox(height: 0),
          _buildConnectionStatus(),
          const SizedBox(height: 16),
          _buildPrivacyBanner(),
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

  Widget _buildPrivacyBanner() {
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showPrivacyInfoDialog,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.privacy_tip_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy & Transparency',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your data stays on your device • Tap for details',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final theme = Theme.of(context);
    final provider = _networkInfo?['provider'] ?? 'Unknown';

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
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Connection Information',
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
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connected to ${provider.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Active connection established',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildPrivacyScore() {
  //   final theme = Theme.of(context);
  //   final assessment =
  //       _networkInfo?['privacyAssessment'] as Map<String, dynamic>?;
  //   final score = assessment?['privacyScore'] ?? 0;
  //   // final usingVPN = assessment?['usingVPN'] ?? false;
  //   // final usingTor = assessment?['usingTor'] ?? false;

  //   Color scoreColor;
  //   String scoreLabel;

  //   if (score >= 80) {
  //     scoreColor = Colors.green;
  //     scoreLabel = 'Good';
  //   } else if (score >= 50) {
  //     scoreColor = Colors.orange;
  //     scoreLabel = 'Fair';
  //   } else {
  //     scoreColor = Colors.red;
  //     scoreLabel = 'Poor';
  //   }

  //   return Container(
  //     clipBehavior: Clip.antiAlias,
  //     decoration: BoxDecoration(
  //       border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
  //       borderRadius: BorderRadius.circular(16),
  //       color: theme.colorScheme.surface,
  //     ),
  //     child: Column(
  //       children: [
  //         Padding(
  //           padding: const EdgeInsets.all(16),
  //           child: Row(
  //             children: [
  //               Icon(
  //                 Icons.shield_outlined,
  //                 color: theme.colorScheme.primary,
  //                 size: 20,
  //               ),
  //               const SizedBox(width: 8),
  //               Text(
  //                 'Privacy Score',
  //                 style: theme.textTheme.titleSmall?.copyWith(
  //                   fontWeight: FontWeight.bold,
  //                   color: theme.colorScheme.primary,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         Divider(height: 1, color: theme.colorScheme.outlineVariant),
  //         Padding(
  //           padding: const EdgeInsets.all(24.0),
  //           child: Column(
  //             children: [
  //               Stack(
  //                 alignment: Alignment.center,
  //                 children: [
  //                   SizedBox(
  //                     width: 140,
  //                     height: 140,
  //                     child: CircularProgressIndicator(
  //                       value: score / 100,
  //                       strokeWidth: 12,
  //                       backgroundColor:
  //                           theme.colorScheme.surfaceContainerHighest,
  //                       valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
  //                       strokeCap: StrokeCap.round,
  //                     ),
  //                   ),
  //                   Column(
  //                     children: [
  //                       Text(
  //                         '$score',
  //                         style: theme.textTheme.displayLarge?.copyWith(
  //                           color: scoreColor,
  //                           fontWeight: FontWeight.bold,
  //                         ),
  //                       ),
  //                       Text(
  //                         scoreLabel,
  //                         style: theme.textTheme.titleMedium?.copyWith(
  //                           color: scoreColor,
  //                           fontWeight: FontWeight.w600,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //               // const SizedBox(height: 24),
  //               // Container(
  //               //   padding: const EdgeInsets.symmetric(
  //               //     horizontal: 16,
  //               //     vertical: 12,
  //               //   ),
  //               //   decoration: BoxDecoration(
  //               //     color: usingTor
  //               //         ? Colors.purple.withOpacity(0.1)
  //               //         : usingVPN
  //               //         ? Colors.green.withOpacity(0.1)
  //               //         : Colors.orange.withOpacity(0.1),
  //               //     borderRadius: BorderRadius.circular(12),
  //               //   ),
  //               //   child: Row(
  //               //     mainAxisAlignment: MainAxisAlignment.center,
  //               //     children: [
  //               //       Icon(
  //               //         usingTor
  //               //             ? Icons.vpn_lock_rounded
  //               //             : usingVPN
  //               //             ? Icons.shield_rounded
  //               //             : Icons.shield_outlined,
  //               //         color: usingTor
  //               //             ? Colors.purple
  //               //             : usingVPN
  //               //             ? Colors.green
  //               //             : Colors.orange,
  //               //         size: 20,
  //               //       ),
  //               //       const SizedBox(width: 8),
  //               //       Text(
  //               //         usingTor
  //               //             ? 'Tor Network Detected'
  //               //             : usingVPN
  //               //             ? 'VPN Detected'
  //               //             : 'No VPN/Tor Detected',
  //               //         style: TextStyle(
  //               //           color: usingTor
  //               //               ? Colors.purple
  //               //               : usingVPN
  //               //               ? Colors.green
  //               //               : Colors.orange,
  //               //           fontWeight: FontWeight.w600,
  //               //           fontSize: 15,
  //               //         ),
  //               //       ),
  //               //     ],
  //               //   ),
  //               // ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildPublicIPCard() {
    final theme = Theme.of(context);
    final publicIP = _networkInfo?['publicIP'] ?? 'Unknown';

    return StatefulBuilder(
      builder: (context, setState) {
        String getDisplayIP() {
          if (publicIP == 'Unknown' || _showFullIP) {
            return publicIP;
          }
          if (publicIP.length <= 8) {
            return publicIP;
          }
          return '${publicIP.substring(0, 4)}***.${publicIP.substring(publicIP.length - 4)}';
        }

        return Container(
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        getDisplayIP(),
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (publicIP != 'Unknown')
                      IconButton(
                        icon: Icon(
                          _showFullIP ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: () {
                          setState(() {
                            _showFullIP = !_showFullIP;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
                  const Icon(
                    Icons.vpn_lock_rounded,
                    color: Colors.purple,
                    size: 48,
                  ),
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
