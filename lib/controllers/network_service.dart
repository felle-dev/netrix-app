import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ip_provider.dart';

class NetworkService {
  Future<Map<String, dynamic>> gatherNetworkInfo(IPProvider provider) async {
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
      info['publicIP'] = 'Unable to fetch from ${provider.name}: $e';
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
      'lat': data['lat'] ?? data['latitude'],
      'lon': data['lon'] ?? data['longitude'],
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
      'lat': data['lat'],
      'lon': data['lon'],
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
        'vpn',
        'virtual private network',
        'virtual private',
        'proxy',
        'anonymous',
        'anonymizer',
        'anonymize',
        'datacenter',
        'data center',
        'data centre',
        'hosting',
        'server',
        'cloud',
        'digitalocean',
        'linode',
        'vultr',
        'ovh',
        'ovhcloud',
        'hetzner',
        'contabo',
        'amazon',
        'aws',
        'ec2',
        'google cloud',
        'gcp',
        'azure',
        'cloudflare',
        'cf',
        'nordvpn',
        'nord vpn',
        'expressvpn',
        'express vpn',
        'surfshark',
        'protonvpn',
        'proton vpn',
        'proton',
        'mullvad',
        'private internet access',
        'pia',
        'cyberghost',
        'ipvanish',
        'vyprvpn',
        'tunnelbear',
        'windscribe',
        'hotspot shield',
        'zenmate',
        'hide.me',
        'ivpn',
        'perfect privacy',
        'airvpn',
        'torguard',
        'openvpn',
        'open vpn',
        'wireguard',
        'wire guard',
        'tor',
        'onion',
        'privacy',
        'private',
        'secure',
        'protected',
        'shield',
        'tunnel',
        'relay',
        'node',
        'exit node',
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
          'AS62744',
          'AS51167',
          'AS14061',
          'AS16276',
          'AS24940',
          'AS20473',
          'AS63949',
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
      baseScore = 100;
    } else if (isVPN) {
      baseScore = 85;
    } else {
      baseScore = (100 - (warnings.length * 20)).clamp(0, 100);
    }
    return baseScore;
  }
}
