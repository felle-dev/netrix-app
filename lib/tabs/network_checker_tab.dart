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
  int _selectedProviderIndex = 0;
  List<IPProvider> _providers = [];

  List<IPProvider> get _allProviders => _providers;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  List<IPProvider> _getDefaultProviders() {
    return [
      // IPProvider(
      //   name: 'ipify',
      //   ipUrl: 'https://api.ipify.org?format=json',
      //   detailsUrl: 'https://ipapi.co/{ip}/json/',
      //   ipJsonKey: 'ip',
      // ),
      // IPProvider(
      //   name: 'ipapi',
      //   ipUrl: 'https://ipapi.co/json/',
      //   detailsUrl: '',
      //   ipJsonKey: 'ip',
      // ),
      IPProvider(
        name: 'ip-api',
        ipUrl: 'http://ip-api.com/json/',
        detailsUrl: '',
        ipJsonKey: 'query',
      ),
      // IPProvider(
      //   name: 'seeip',
      //   ipUrl: 'https://api.seeip.org/jsonip',
      //   detailsUrl: 'https://ipapi.co/{ip}/json/',
      //   ipJsonKey: 'ip',
      // ),
      // IPProvider(
      //   name: 'myip',
      //   ipUrl: 'https://api.myip.com',
      //   detailsUrl: 'https://ipapi.co/{ip}/json/',
      //   ipJsonKey: 'ip',
      // ),
      // IPProvider(
      //   name: 'ipgeolocation',
      //   ipUrl: 'https://api.ipgeolocation.io/getip',
      //   detailsUrl: 'https://ipapi.co/{ip}/json/',
      //   ipJsonKey: 'ip',
      // ),
      // IPProvider(
      //   name: 'ifconfig',
      //   ipUrl: 'https://ifconfig.me/all.json',
      //   detailsUrl: 'https://ipapi.co/{ip}/json/',
      //   ipJsonKey: 'ip_addr',
      // ),
    ];
  }

  Future<void> _loadProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final providersJson = prefs.getString('providers');

    if (providersJson != null) {
      final List<dynamic> decoded = json.decode(providersJson);
      setState(() {
        _providers = decoded.map((e) => IPProvider.fromJson(e)).toList();
        _selectedProviderIndex = prefs.getInt('selected_provider_index') ?? 0;
        if (_selectedProviderIndex >= _providers.length) {
          _selectedProviderIndex = 0;
        }
      });
    } else {
      // Initialize with default providers
      setState(() {
        _providers = _getDefaultProviders();
      });
      await _saveProviders();
    }

    _checkNetwork();
  }

  Future<void> _saveProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_providers.map((e) => e.toJson()).toList());
    await prefs.setString('providers', encoded);
    await prefs.setInt('selected_provider_index', _selectedProviderIndex);
  }

  Future<void> _checkNetwork() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final info = await _gatherNetworkInfo();
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

    // Get public IP information using selected provider
    String? publicIP;
    try {
      final provider = _allProviders[_selectedProviderIndex];
      final response = await http
          .get(Uri.parse(provider.ipUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        publicIP = data[provider.ipJsonKey];

        if (publicIP != null) {
          info['publicIP'] = publicIP;
          info['provider'] = provider.name;
          info['providerUrl'] = provider.ipUrl;

          // Get detailed IP information
          await _getIPDetails(publicIP, info, provider);
        }
      }
    } catch (e) {
      info['publicIP'] =
          'Unable to fetch from ${_allProviders[_selectedProviderIndex].name}: $e';
    }

    if (publicIP == null) {
      info['publicIP'] = 'Unable to fetch from selected provider';
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ProviderSettingsPage(
          providers: _providers,
          selectedProviderIndex: _selectedProviderIndex,
          onSelectProvider: (index) async {
            setState(() {
              _selectedProviderIndex = index;
            });
            await _saveProviders();
            _checkNetwork();
          },
          onAddProvider: (provider) async {
            setState(() {
              _providers.add(provider);
            });
            await _saveProviders();
          },
          onDeleteProvider: (index) async {
            if (_providers.length <= 1) {
              return false;
            }

            setState(() {
              _providers.removeAt(index);
              if (_selectedProviderIndex >= _providers.length) {
                _selectedProviderIndex = _providers.length - 1;
              }
            });
            await _saveProviders();
            return true;
          },
          onResetToDefaults: () async {
            setState(() {
              _providers = _getDefaultProviders();
              _selectedProviderIndex = 0;
            });
            await _saveProviders();
            _checkNetwork();
          },
        ),
      ),
    );
  }

  void _showPrivacyInfoDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const _PrivacyInfoPage()),
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
          _buildIPDetailsCard(),
          const SizedBox(height: 16),
          _buildLocalAddressesCard(),
          const SizedBox(height: 16),
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

    // Debug information
    final hasNetworkInfo = _networkInfo != null;
    final detailsType = details?.runtimeType.toString() ?? 'null';
    final isDetailsMap = details is Map;

    if (details is! Map) {
      return GestureDetector(
        onTap: () => _showDebugInfoDialog(),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: theme.colorScheme.errorContainer.withOpacity(0.3),
            border: Border.all(
              color: theme.colorScheme.error.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bug_report_rounded,
                      color: theme.colorScheme.error,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Not Available',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debug Information:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDebugRow(
                        theme,
                        'Network Info',
                        hasNetworkInfo ? '✓ Available' : '✗ Missing',
                      ),
                      _buildDebugRow(theme, 'Public IP', publicIP),
                      _buildDebugRow(theme, 'Details Type', detailsType),
                      _buildDebugRow(theme, 'Is Map', isDetailsMap.toString()),
                      if (_networkInfo != null) ...[
                        _buildDebugRow(
                          theme,
                          'Provider',
                          _networkInfo!['provider']?.toString() ?? 'null',
                        ),
                        _buildDebugRow(
                          theme,
                          'Provider URL',
                          _networkInfo!['providerUrl']?.toString() ?? 'null',
                        ),
                      ],
                      if (_errorMessage != null)
                        _buildDebugRow(theme, 'Error', _errorMessage!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap for full debug details',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
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
          color: isTor
              ? Colors.purple.withOpacity(0.15)
              : theme.colorScheme.primaryContainer.withOpacity(0.5),
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
    final details = _networkInfo?['ipDetails'];
    if (details is! Map) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _LocationDetailsPage(
          details: Map<String, dynamic>.from(details),
          publicIP: _networkInfo?['publicIP'] ?? 'Unknown',
        ),
      ),
    );
  }

  Widget _buildDebugRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDebugInfoDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DebugInfoPage(
          networkInfo: _networkInfo,
          selectedProviderIndex: _selectedProviderIndex,
          allProviders: _allProviders,
          isLoading: _isLoading,
          errorMessage: _errorMessage,
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final theme = Theme.of(context);
    final provider =
        _networkInfo?['provider'] ?? _allProviders[_selectedProviderIndex].name;

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
                        color: _networkInfo != null
                            ? Colors.green
                            : Colors.orange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_networkInfo != null
                                        ? Colors.green
                                        : Colors.orange)
                                    .withOpacity(0.5),
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
                            'Using ${provider.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _networkInfo != null
                                ? 'Active connection established'
                                : 'Tap Providers to change',
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
                const Spacer(),
                InkWell(
                  onTap: _showLocalAddressExplanationDialog,
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

  void _showLocalAddressExplanationDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const _LocalAddressExplanationPage(),
      ),
    );
  }
}

// Provider Settings Page (was bottom sheet)
class _ProviderSettingsPage extends StatefulWidget {
  final List<IPProvider> providers;
  final int selectedProviderIndex;
  final Function(int) onSelectProvider;
  final Function(IPProvider) onAddProvider;
  final Future<bool> Function(int) onDeleteProvider;
  final Function() onResetToDefaults;

  const _ProviderSettingsPage({
    required this.providers,
    required this.selectedProviderIndex,
    required this.onSelectProvider,
    required this.onAddProvider,
    required this.onDeleteProvider,
    required this.onResetToDefaults,
  });

  @override
  State<_ProviderSettingsPage> createState() => _ProviderSettingsPageState();
}

class _ProviderSettingsPageState extends State<_ProviderSettingsPage> {
  final _nameController = TextEditingController();
  final _ipUrlController = TextEditingController();
  final _detailsUrlController = TextEditingController();
  final _jsonKeyController = TextEditingController();

  late List<IPProvider> _providers;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _providers = List.from(widget.providers);
    _selectedIndex = widget.selectedProviderIndex;
  }

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
                final provider = IPProvider(
                  name: _nameController.text,
                  ipUrl: _ipUrlController.text,
                  detailsUrl: _detailsUrlController.text,
                  ipJsonKey: _jsonKeyController.text,
                );

                widget.onAddProvider(provider);
                setState(() {
                  _providers.add(provider);
                });

                _nameController.clear();
                _ipUrlController.clear();
                _detailsUrlController.clear();
                _jsonKeyController.clear();
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Provider added successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will restore all default providers and remove any custom providers you\'ve added. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onResetToDefaults();
              Navigator.pop(context); // Close the settings page
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IP Provider Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to defaults',
            onPressed: _showResetConfirmDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add provider',
            onPressed: _showAddProviderDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Select which provider to use for checking your IP',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          if (_providers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.dns_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No providers available',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add a provider',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._providers.asMap().entries.map((entry) {
              final index = entry.key;
              final provider = entry.value;
              final isSelected = _selectedIndex == index;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                      widget.onSelectProvider(index);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  provider.ipUrl,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.error,
                            ),
                            onPressed: () async {
                              final deleted = await widget.onDeleteProvider(
                                index,
                              );
                              if (!deleted && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Cannot delete the last provider',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } else if (mounted) {
                                setState(() {
                                  _providers.removeAt(index);
                                  if (_selectedIndex >= _providers.length) {
                                    _selectedIndex = _providers.length - 1;
                                  }
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Provider deleted'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.tertiary.withOpacity(0.2),
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
                    'Select a provider and the app will use it for all checks. You can delete any provider except the last one.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Privacy Info Page (was bottom sheet)
class _PrivacyInfoPage extends StatelessWidget {
  const _PrivacyInfoPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Transparency')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
        ],
      ),
    );
  }
}

class _LocationDetailsPage extends StatelessWidget {
  final Map<String, dynamic> details;
  final String publicIP;

  const _LocationDetailsPage({required this.details, required this.publicIP});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final country = details['country'] ?? 'Unknown';
    final region = details['region'] ?? 'Unknown';
    final city = details['city'] ?? 'Unknown';
    final isp = details['isp'] ?? 'Unknown';
    final timezone = details['timezone'] ?? 'Unknown';
    final isTor = details['isTor'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTor ? 'Tor Exit Node Details' : 'Location Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
        ],
      ),
    );
  }
}

class _LocalAddressExplanationPage extends StatelessWidget {
  const _LocalAddressExplanationPage();

  Widget _buildAddressTypeRow(
    ThemeData theme,
    String type,
    String example,
    String description,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                type,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Text(
              example,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 60, top: 2),
          child: Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInterfaceRow(ThemeData theme, String name, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.network_check, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Local Network Addresses')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'What are Local Addresses?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Local network addresses (also called private IP addresses) are used to identify your device within your home or office network. They are NOT visible to the internet.',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Common Types
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
                      'Common Address Types',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAddressTypeRow(
                  theme,
                  'IPv4',
                  '192.168.x.x, 10.0.x.x',
                  'Most common for home networks',
                ),
                const SizedBox(height: 8),
                _buildAddressTypeRow(
                  theme,
                  'IPv6',
                  'fe80::...',
                  'Newer protocol, much longer addresses',
                ),
                const SizedBox(height: 8),
                _buildAddressTypeRow(
                  theme,
                  'Loopback',
                  '127.0.0.1',
                  'Points to your own device',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Public vs Local
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
                      Icons.compare_arrows_rounded,
                      color: theme.colorScheme.tertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Local vs Public',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'Local Address: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                      const TextSpan(
                        text:
                            'Only works inside your network (e.g., 192.168.1.5). Your phone, laptop, and printer all have different local addresses.\n\n',
                      ),
                      TextSpan(
                        text: 'Public IP: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                      const TextSpan(
                        text:
                            'Visible to the entire internet. All devices in your home share the same public IP when accessing websites.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Network Interfaces
          Text(
            'Network Interfaces',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Each connection method has its own address:',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _buildInterfaceRow(theme, 'WiFi (wlan0, en0)', 'Wireless connection'),
          const SizedBox(height: 8),
          _buildInterfaceRow(theme, 'Ethernet (eth0, en1)', 'Wired connection'),
          const SizedBox(height: 8),
          _buildInterfaceRow(theme, 'Loopback (lo)', 'Internal testing'),

          const SizedBox(height: 20),

          // Privacy Note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.secondary.withOpacity(0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: theme.colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy Note',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Local addresses are private and safe to share within your network. However, IPv6 addresses can sometimes leak your location even when using a VPN. Check the Privacy Assessment for warnings.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSecondaryContainer,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DebugInfoPage extends StatelessWidget {
  final Map<String, dynamic>? networkInfo;
  final int selectedProviderIndex;
  final List<IPProvider> allProviders;
  final bool isLoading;
  final String? errorMessage;

  const _DebugInfoPage({
    required this.networkInfo,
    required this.selectedProviderIndex,
    required this.allProviders,
    required this.isLoading,
    this.errorMessage,
  });

  Widget _buildDebugRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Debug Information')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Icon(
                Icons.bug_report_rounded,
                color: theme.colorScheme.error,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Debug Information',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Selected Provider
          Text(
            'Selected Provider',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDebugRow(
                  theme,
                  'Index',
                  selectedProviderIndex.toString(),
                ),
                _buildDebugRow(
                  theme,
                  'Name',
                  allProviders[selectedProviderIndex].name,
                ),
                _buildDebugRow(
                  theme,
                  'URL',
                  allProviders[selectedProviderIndex].ipUrl,
                ),
                _buildDebugRow(
                  theme,
                  'JSON Key',
                  allProviders[selectedProviderIndex].ipJsonKey,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Network Info
          Text(
            'Network Info State',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDebugRow(
                  theme,
                  'Is Null',
                  (networkInfo == null).toString(),
                ),
                _buildDebugRow(theme, 'Is Loading', isLoading.toString()),
                if (errorMessage != null)
                  _buildDebugRow(theme, 'Error', errorMessage!),
                if (networkInfo != null) ...[
                  _buildDebugRow(theme, 'Keys', networkInfo!.keys.join(', ')),
                  _buildDebugRow(
                    theme,
                    'Public IP',
                    networkInfo!['publicIP']?.toString() ?? 'null',
                  ),
                  _buildDebugRow(
                    theme,
                    'Provider',
                    networkInfo!['provider']?.toString() ?? 'null',
                  ),
                  _buildDebugRow(
                    theme,
                    'Provider URL',
                    networkInfo!['providerUrl']?.toString() ?? 'null',
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // IP Details
          Text(
            'IP Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (networkInfo?['ipDetails'] == null)
                  _buildDebugRow(theme, 'Status', 'NULL - This is the problem!')
                else if (networkInfo!['ipDetails'] is! Map)
                  _buildDebugRow(
                    theme,
                    'Type',
                    networkInfo!['ipDetails'].runtimeType.toString(),
                  )
                else ...[
                  _buildDebugRow(theme, 'Type', 'Map (correct)'),
                  ...(networkInfo!['ipDetails'] as Map).entries.map(
                    (e) => _buildDebugRow(
                      theme,
                      e.key.toString(),
                      e.value?.toString() ?? 'null',
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Raw JSON
          Text(
            'Raw Data (JSON)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              networkInfo != null
                  ? const JsonEncoder.withIndent('  ').convert(networkInfo)
                  : 'null',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
