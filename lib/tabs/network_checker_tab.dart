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
    bool isTor = false;
    String? torDetectionMethod;

    // Method 1: Check organization name
    final org = data['org']?.toLowerCase() ?? '';
    final isp = data['org']?.toLowerCase() ?? data['isp']?.toLowerCase() ?? '';

    if (org.contains('tor') ||
        org.contains('onion') ||
        isp.contains('tor') ||
        isp.contains('onion')) {
      isTor = true;
      torDetectionMethod = 'Organization name';
    }

    // Method 2: Check against Tor Project API
    if (!isTor) {
      try {
        final torCheckResponse = await http
            .get(Uri.parse('https://check.torproject.org/api/ip'))
            .timeout(const Duration(seconds: 5));

        if (torCheckResponse.statusCode == 200) {
          final torData = json.decode(torCheckResponse.body);
          if (torData['IsTor'] == true) {
            isTor = true;
            torDetectionMethod = 'Tor Project API';
          }
        }
      } catch (e) {
        // Continue to next method
      }
    }

    // Method 3: Check against alternative Tor detection service
    if (!isTor) {
      try {
        final torCheckResponse = await http
            .get(Uri.parse('https://www.dan.me.uk/torcheck?ip=$ip'))
            .timeout(const Duration(seconds: 5));

        if (torCheckResponse.statusCode == 200) {
          final body = torCheckResponse.body.toLowerCase();
          if (body.contains('tor exit') || body.contains('is a tor')) {
            isTor = true;
            torDetectionMethod = 'Dan.me.uk Tor check';
          }
        }
      } catch (e) {
        // Continue to next method
      }
    }

    // Method 4: Check ASN (Autonomous System Number) for known Tor ASNs
    if (!isTor) {
      final asn = data['asn']?.toString() ?? '';
      final knownTorASNs = ['AS197', 'AS200019', 'AS205100', 'AS44066'];
      if (knownTorASNs.any((torAsn) => asn.contains(torAsn))) {
        isTor = true;
        torDetectionMethod = 'Known Tor ASN';
      }
    }

    info['ipDetails'] = {
      'ip': ip,
      'country': data['country_name'] ?? data['country'] ?? 'Unknown',
      'region': data['region'] ?? 'Unknown',
      'city': data['city'] ?? 'Unknown',
      'isp': data['org'] ?? data['isp'] ?? data['organization'] ?? 'Unknown',
      'timezone': data['timezone'] ?? 'Unknown',
      'isTor': isTor,
      if (torDetectionMethod != null) 'torDetectionMethod': torDetectionMethod,
      if (data['asn'] != null) 'asn': data['asn'],
      if (data['org'] != null) 'org': data['org'],
      if (data['organization'] != null) 'organization': data['organization'],
    };
  }

  Future<void> _parseIPApiDetails(
    String ip,
    Map<String, dynamic> data,
    Map<String, dynamic> info,
  ) async {
    bool isTor = false;
    String? torDetectionMethod;

    // Method 1: Check organization name
    final org = data['org']?.toLowerCase() ?? '';
    final isp = data['isp']?.toLowerCase() ?? '';
    if (org.contains('tor') ||
        org.contains('onion') ||
        isp.contains('tor') ||
        isp.contains('onion')) {
      isTor = true;
      torDetectionMethod = 'Organization/ISP name';
    }

    // Method 2: Check against Tor Project API
    if (!isTor) {
      try {
        final torCheckResponse = await http
            .get(Uri.parse('https://check.torproject.org/api/ip'))
            .timeout(const Duration(seconds: 5));

        if (torCheckResponse.statusCode == 200) {
          final torData = json.decode(torCheckResponse.body);
          if (torData['IsTor'] == true) {
            isTor = true;
            torDetectionMethod = 'Tor Project API';
          }
        }
      } catch (e) {
        // Continue to next method
      }
    }

    // Method 3: Check against alternative Tor detection service
    if (!isTor) {
      try {
        final torCheckResponse = await http
            .get(Uri.parse('https://www.dan.me.uk/torcheck?ip=$ip'))
            .timeout(const Duration(seconds: 5));

        if (torCheckResponse.statusCode == 200) {
          final body = torCheckResponse.body.toLowerCase();
          if (body.contains('tor exit') || body.contains('is a tor')) {
            isTor = true;
            torDetectionMethod = 'Dan.me.uk Tor check';
          }
        }
      } catch (e) {
        // Continue to next method
      }
    }

    // Method 4: Check ASN for known Tor ASNs
    if (!isTor) {
      final as_field = data['as']?.toString() ?? '';
      final knownTorASNs = ['AS197', 'AS200019', 'AS205100', 'AS44066'];
      if (knownTorASNs.any((torAsn) => as_field.contains(torAsn))) {
        isTor = true;
        torDetectionMethod = 'Known Tor ASN';
      }
    }

    info['ipDetails'] = {
      'ip': ip,
      'country': data['country'] ?? 'Unknown',
      'region': data['regionName'] ?? 'Unknown',
      'city': data['city'] ?? 'Unknown',
      'isp': data['isp'] ?? 'Unknown',
      'timezone': data['timezone'] ?? 'Unknown',
      'isTor': isTor,
      if (torDetectionMethod != null) 'torDetectionMethod': torDetectionMethod,
      if (data['as'] != null) 'asn': data['as'],
      if (data['org'] != null) 'org': data['org'],
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
    bool isVPN = false;
    String? detectionMethod;

    if (info['ipDetails'] is Map) {
      isTor = info['ipDetails']['isTor'] ?? false;
      final isp = info['ipDetails']['isp']?.toString().toLowerCase() ?? '';
      final org = info['ipDetails']['org']?.toString().toLowerCase() ?? '';
      final organization =
          info['ipDetails']['organization']?.toString().toLowerCase() ?? '';

      // Combine all fields for comprehensive checking
      final combinedInfo = '$isp $org $organization'.toLowerCase();

      // Enhanced VPN detection patterns
      final vpnPatterns = [
        // Explicit VPN services
        'vpn', 'virtual private network', 'virtual private',
        // Proxy services
        'proxy', 'anonymous', 'anonymizer', 'anonymize',
        // Cloud/hosting providers commonly used by VPNs
        'datacenter',
        'data center',
        'data centre',
        'hosting',
        'server',
        'cloud',
        'digitalocean', 'linode', 'vultr', 'ovh', 'ovhcloud',
        'hetzner', 'contabo', 'amazon', 'aws', 'ec2',
        'google cloud', 'gcp', 'azure', 'cloudflare', 'cf',
        // VPN provider names
        'nordvpn', 'nord vpn', 'expressvpn', 'express vpn',
        'surfshark', 'protonvpn', 'proton vpn', 'proton',
        'mullvad', 'private internet access', 'pia',
        'cyberghost', 'ipvanish', 'vyprvpn', 'tunnelbear',
        'windscribe', 'hotspot shield', 'zenmate', 'hide.me',
        'ivpn', 'perfect privacy', 'airvpn', 'torguard',
        // OpenVPN
        'openvpn', 'open vpn', 'wireguard', 'wire guard',
        // Tor-related (backup detection)
        'tor', 'onion',
        // Other privacy services
        'privacy', 'private', 'secure', 'protected', 'shield',
        // Additional indicators
        'tunnel', 'relay', 'node', 'exit node',
      ];

      for (final pattern in vpnPatterns) {
        if (combinedInfo.contains(pattern)) {
          isVPN = true;
          detectionMethod = 'Detected "$pattern" in connection info';
          break;
        }
      }

      // Additional ASN-based detection for known VPN/hosting providers
      if (!isVPN && info['ipDetails']['asn'] != null) {
        final asn = info['ipDetails']['asn'].toString();
        final knownVpnASNs = [
          'AS62744', // Mullvad
          'AS51167', // Contabo
          'AS14061', // DigitalOcean
          'AS16276', // OVH
          'AS24940', // Hetzner
          'AS20473', // Vultr
          'AS63949', // Linode
        ];

        if (knownVpnASNs.any((vpnAsn) => asn.contains(vpnAsn))) {
          isVPN = true;
          detectionMethod = 'Known VPN/hosting provider ASN detected';
        }
      }

      assessment['usingVPN'] = isVPN;
      assessment['usingTor'] = isTor;
      if (detectionMethod != null) {
        assessment['detectionMethod'] = detectionMethod;
      }

      if (!isVPN && !isTor) {
        warnings.add('Direct connection - Your real IP is visible');
        tips.add('Consider using a VPN or Tor for enhanced privacy');
      } else if (isVPN && !isTor) {
        tips.add('VPN detected - Your real IP is hidden from websites');
      } else if (isTor) {
        tips.add('Tor detected - Maximum anonymity active');
      }
    }

    if (info['localAddresses'] is List) {
      final hasIPv6 = (info['localAddresses'] as List).any(
        (addr) => addr['type'] == 'IPv6' && addr['isLinkLocal'] == 'false',
      );

      if (hasIPv6 && !isTor) {
        warnings.add('IPv6 leak detected - May bypass VPN protection');
        tips.add('Disable IPv6 or ensure your VPN supports it');
      }
    }

    assessment['warnings'] = warnings;
    assessment['tips'] = tips;
    assessment['privacyScore'] = _calculatePrivacyScore(warnings, isTor, isVPN);

    return assessment;
  }

  int _calculatePrivacyScore(List<String> warnings, bool isTor, bool isVPN) {
    int baseScore = 100;
    if (isTor) {
      baseScore = 100; // Maximum privacy
    } else if (isVPN) {
      baseScore = 85; // Good privacy
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

  void _showPrivacyScoreDialog() {
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
                        Icons.help_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Privacy Score Explained',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'How Your Score is Calculated',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildScoreExplanationRow(
                    theme,
                    '100/100',
                    'Tor Network',
                    Colors.purple,
                    'Maximum anonymity. Your connection is routed through multiple encrypted relays, making it extremely difficult to trace.',
                  ),
                  const SizedBox(height: 12),
                  _buildScoreExplanationRow(
                    theme,
                    '85/100',
                    'VPN Active',
                    Colors.blue,
                    'Good privacy. Your real IP is hidden behind a VPN server. Choose reputable VPN providers for best protection.',
                  ),
                  const SizedBox(height: 12),
                  _buildScoreExplanationRow(
                    theme,
                    '0-80/100',
                    'Direct Connection',
                    Colors.red,
                    'Your real IP is exposed. Websites can see your location and ISP. Score decreases with privacy issues like IPv6 leaks.',
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(
                        0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Detection Method',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We detect VPNs and Tor by analyzing:\n'
                          '• ISP and organization names\n'
                          '• Known VPN provider patterns (ProtonVPN, NordVPN, etc.)\n'
                          '• Hosting/datacenter identifiers\n'
                          '• Autonomous System Numbers (ASNs)\n'
                          '• Tor Project official API',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: theme.colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Important Note',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When running on web browsers, this app can only analyze what public IP services report. Some VPNs may not be detected if they don\'t identify themselves in the connection metadata. For most accurate detection, check the ISP field in "IP Location Details" - it should show your VPN provider\'s name.',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildScoreExplanationRow(
    ThemeData theme,
    String score,
    String label,
    Color color,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              score,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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
          _buildIPLocationFocusCard(),
          const SizedBox(height: 16),
          _buildPrivacyAssessmentCard(),
          const SizedBox(height: 16),
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

  Widget _buildIPLocationFocusCard() {
    final theme = Theme.of(context);
    final details = _networkInfo?['ipDetails'];
    final publicIP = _networkInfo?['publicIP'] ?? 'Unknown';

    if (details is! Map) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_off_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Location Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Not Available',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final country = details['country'] ?? 'Unknown';
    final city = details['city'] ?? 'Unknown';
    final isTor = details['isTor'] == true;

    return GestureDetector(
      onTap: () => _showLocationExplanationDialog(),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isTor
                ? [
                    Colors.purple.withOpacity(0.3),
                    Colors.deepPurple.withOpacity(0.2),
                  ]
                : [
                    theme.colorScheme.primaryContainer.withOpacity(0.8),
                    theme.colorScheme.tertiaryContainer.withOpacity(0.6),
                  ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isTor
                            ? Icons.vpn_lock_rounded
                            : Icons.location_on_rounded,
                        color: isTor
                            ? Colors.purple
                            : theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isTor ? 'Your Tor Exit Location' : 'Your Location',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    _getCountryFlag(country),
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          country,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (city != 'Unknown') ...[
                          const SizedBox(height: 4),
                          Text(
                            city,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.public_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatefulBuilder(
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

                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  getDisplayIP(),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (publicIP != 'Unknown')
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _showFullIP = !_showFullIP;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      _showFullIP
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (isTor) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 16,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your real location is hidden by Tor',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.w500,
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
      ),
    );
  }

  String _getCountryFlag(String country) {
    // Map common country names to flag emojis
    final countryFlags = {
      'United States': '🇺🇸',
      'United Kingdom': '🇬🇧',
      'Canada': '🇨🇦',
      'Australia': '🇦🇺',
      'Germany': '🇩🇪',
      'France': '🇫🇷',
      'Italy': '🇮🇹',
      'Spain': '🇪🇸',
      'Netherlands': '🇳🇱',
      'Switzerland': '🇨🇭',
      'Sweden': '🇸🇪',
      'Norway': '🇳🇴',
      'Denmark': '🇩🇰',
      'Finland': '🇫🇮',
      'Poland': '🇵🇱',
      'Russia': '🇷🇺',
      'China': '🇨🇳',
      'Japan': '🇯🇵',
      'South Korea': '🇰🇷',
      'India': '🇮🇳',
      'Indonesia': '🇮🇩',
      'Singapore': '🇸🇬',
      'Malaysia': '🇲🇾',
      'Thailand': '🇹🇭',
      'Vietnam': '🇻🇳',
      'Philippines': '🇵🇭',
      'Brazil': '🇧🇷',
      'Argentina': '🇦🇷',
      'Mexico': '🇲🇽',
      'Chile': '🇨🇱',
      'South Africa': '🇿🇦',
      'Egypt': '🇪🇬',
      'Turkey': '🇹🇷',
      'Israel': '🇮🇱',
      'UAE': '🇦🇪',
      'Saudi Arabia': '🇸🇦',
      'New Zealand': '🇳🇿',
    };

    return countryFlags[country] ?? '🌍';
  }

  void _showLocationExplanationDialog() {
    final theme = Theme.of(context);
    final details = _networkInfo?['ipDetails'];
    final publicIP = _networkInfo?['publicIP'] ?? 'Unknown';

    if (details is! Map) return;

    final country = details['country'] ?? 'Unknown';
    final region = details['region'] ?? 'Unknown';
    final city = details['city'] ?? 'Unknown';
    final isp = details['isp'] ?? 'Unknown';
    final timezone = details['timezone'] ?? 'Unknown';
    final isTor = details['isTor'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                    Text(
                      _getCountryFlag(country),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isTor ? 'Tor Exit Node Details' : 'Location Details',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildLocationDetailRow(
                  theme,
                  Icons.public_rounded,
                  'IP Address',
                  publicIP,
                  theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                _buildLocationDetailRow(
                  theme,
                  Icons.flag_rounded,
                  'Country',
                  country,
                  Colors.blue,
                ),
                if (region != 'Unknown') ...[
                  const SizedBox(height: 16),
                  _buildLocationDetailRow(
                    theme,
                    Icons.map_rounded,
                    'Region',
                    region,
                    Colors.teal,
                  ),
                ],
                if (city != 'Unknown') ...[
                  const SizedBox(height: 16),
                  _buildLocationDetailRow(
                    theme,
                    Icons.location_city_rounded,
                    'City',
                    city,
                    Colors.orange,
                  ),
                ],
                const SizedBox(height: 16),
                _buildLocationDetailRow(
                  theme,
                  Icons.business_rounded,
                  'ISP',
                  isp,
                  Colors.purple,
                ),
                if (timezone != 'Unknown') ...[
                  const SizedBox(height: 16),
                  _buildLocationDetailRow(
                    theme,
                    Icons.access_time_rounded,
                    'Timezone',
                    timezone,
                    Colors.green,
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'What is this?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isTor
                            ? 'This shows the location of the Tor exit node that websites see, not your real location. Your actual location is hidden and protected by the Tor network.'
                            : 'This is the location associated with your public IP address. Websites you visit can see this information, which is why using a VPN or Tor is recommended for privacy.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.tertiary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.devices_rounded,
                            color: theme.colorScheme.tertiary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Local vs Public Address',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(
                              text: 'Public IP: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  'Visible to websites and services on the internet. Used for geolocation and identification.\n\n',
                            ),
                            TextSpan(
                              text: 'Local Address: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  'Private IP used only within your home/office network. Not visible to the internet (e.g., 192.168.x.x, 10.0.x.x).',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
      ),
    );
  }

  Widget _buildLocationDetailRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyAssessmentCard() {
    final theme = Theme.of(context);
    final assessment = _networkInfo?['privacyAssessment'];

    if (assessment is! Map) {
      return const SizedBox.shrink();
    }

    final isTor = assessment['usingTor'] == true;
    final isVPN = assessment['usingVPN'] == true;
    final privacyScore = assessment['privacyScore'] ?? 0;
    final warnings = assessment['warnings'] as List? ?? [];
    final tips = assessment['tips'] as List? ?? [];
    final detectionMethod = assessment['detectionMethod'];

    Color scoreColor;
    IconData scoreIcon;
    String scoreLabel;

    if (privacyScore >= 85) {
      scoreColor = Colors.green;
      scoreIcon = Icons.verified_user_rounded;
      scoreLabel = 'Excellent';
    } else if (privacyScore >= 60) {
      scoreColor = Colors.orange;
      scoreIcon = Icons.shield_rounded;
      scoreLabel = 'Good';
    } else {
      scoreColor = Colors.red;
      scoreIcon = Icons.warning_rounded;
      scoreLabel = 'Exposed';
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
                  Icons.security_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Privacy Assessment',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _showPrivacyScoreDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.help_outline_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
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
                // Privacy Score
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scoreColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(scoreIcon, color: scoreColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy Score',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '$privacyScore',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: scoreColor,
                                ),
                              ),
                              Text(
                                '/100',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: scoreColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  scoreLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: scoreColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Protection Status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isTor
                        ? Colors.purple.withOpacity(0.1)
                        : isVPN
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isTor
                          ? Colors.purple.withOpacity(0.3)
                          : isVPN
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isTor
                            ? Icons.vpn_lock_rounded
                            : isVPN
                            ? Icons.vpn_key_rounded
                            : Icons.warning_amber_rounded,
                        color: isTor
                            ? Colors.purple
                            : isVPN
                            ? Colors.blue
                            : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTor
                                  ? 'Tor Network Active'
                                  : isVPN
                                  ? 'VPN Connection Detected'
                                  : 'Direct Connection',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isTor
                                    ? Colors.purple
                                    : isVPN
                                    ? Colors.blue
                                    : Colors.red,
                              ),
                            ),
                            if (detectionMethod != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                detectionMethod,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (warnings.isNotEmpty || tips.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  if (warnings.isNotEmpty)
                    ...warnings.map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                warning,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (tips.isNotEmpty)
                    ...tips.map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tip,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
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
          ...addresses.asMap().entries.map((entry) {
            final addr = entry.value;
            final isLast = entry.key == addresses.length - 1;

            return Column(
              children: [
                ListTile(
                  title: Text(
                    '${addr['interface']} (${addr['type']})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SelectableText(
                      addr['address'],
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: theme.colorScheme.outlineVariant,
                  ),
              ],
            );
          }).toList(),
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
