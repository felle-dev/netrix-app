import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/network_utils.dart';

class LocationDetailsPage extends StatelessWidget {
  final Map<String, dynamic> details;
  final String publicIP;

  const LocationDetailsPage({
    Key? key,
    required this.details,
    required this.publicIP,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTor = details['isTor'] == true;

    // Get coordinates if available
    final lat = details['lat'] ?? details['latitude'];
    final lon = details['lon'] ?? details['longitude'];
    final hasCoordinates = lat != null && lon != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTor ? 'Tor Exit Node Details' : 'Location Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Text(
              NetworkUtils.getCountryFlag(details['country'] ?? 'Unknown'),
              style: const TextStyle(fontSize: 80),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              details['country'] ?? 'Unknown',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Map widget
          if (hasCoordinates) ...[
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    double.parse(lat.toString()),
                    double.parse(lon.toString()),
                  ),
                  initialZoom: 10.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.yourapp.networkchecker',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          double.parse(lat.toString()),
                          double.parse(lon.toString()),
                        ),
                        width: 40,
                        height: 40,
                        child: Icon(
                          isTor ? Icons.vpn_lock : Icons.location_on,
                          color: isTor
                              ? Colors.purple
                              : theme.colorScheme.error,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (isTor) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.vpn_lock_rounded, color: Colors.purple, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Tor Network Detected',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your real location is hidden. The information shown is for the Tor exit node, not your actual location.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          _buildDetailSection(theme, 'IP Address', publicIP),
          if (details['city'] != null && details['city'] != 'Unknown')
            _buildDetailSection(theme, 'City', details['city']),
          if (details['region'] != null && details['region'] != 'Unknown')
            _buildDetailSection(theme, 'Region', details['region']),
          if (details['isp'] != null && details['isp'] != 'Unknown')
            _buildDetailSection(theme, 'ISP', details['isp']),
          if (details['timezone'] != null && details['timezone'] != 'Unknown')
            _buildDetailSection(theme, 'Timezone', details['timezone']),
          if (details['asn'] != null)
            _buildDetailSection(theme, 'ASN', details['asn'].toString()),
          if (details['torDetectionMethod'] != null)
            _buildDetailSection(
              theme,
              'Detection Method',
              details['torDetectionMethod'],
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
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
                      'About This Information',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isTor
                      ? 'This location data represents the Tor exit node that websites see when you browse. '
                            'Your actual location remains private and hidden by the Tor network.'
                      : 'This is the location associated with your public IP address. '
                            'Websites can see this information when you visit them.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }
}
