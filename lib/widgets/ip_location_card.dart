import 'package:flutter/material.dart';
import '../utils/network_utils.dart';
import '../pages/location_details_page.dart';
import '../pages/debug_info_page.dart';

class IPLocationFocusCard extends StatefulWidget {
  final Map<String, dynamic>? networkInfo;
  final String? errorMessage;

  const IPLocationFocusCard({
    Key? key,
    required this.networkInfo,
    this.errorMessage,
  }) : super(key: key);

  @override
  State<IPLocationFocusCard> createState() => _IPLocationFocusCardState();
}

class _IPLocationFocusCardState extends State<IPLocationFocusCard> {
  bool _showFullIP = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = widget.networkInfo?['ipDetails'];
    final publicIP = widget.networkInfo?['publicIP'] ?? 'Unknown';

    if (details is! Map) {
      return _buildDebugCard(theme, publicIP, details);
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
              _buildHeader(theme, isTor),
              const SizedBox(height: 20),
              _buildLocationInfo(theme, country, city),
              const SizedBox(height: 16),
              _buildIPDisplay(theme, publicIP),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isTor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              isTor ? Icons.vpn_lock_rounded : Icons.location_on_rounded,
              color: isTor ? Colors.purple : theme.colorScheme.primary,
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
    );
  }

  Widget _buildLocationInfo(ThemeData theme, String country, String city) {
    return Row(
      children: [
        Text(
          NetworkUtils.getCountryFlag(country),
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
    );
  }

  Widget _buildIPDisplay(ThemeData theme, String publicIP) {
    return Container(
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    NetworkUtils.maskIP(publicIP, _showFullIP),
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
                        _showFullIP ? Icons.visibility : Icons.visibility_off,
                        size: 18,
                        color: theme.colorScheme.primary,
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

  Widget _buildDebugCard(ThemeData theme, String publicIP, dynamic details) {
    final hasNetworkInfo = widget.networkInfo != null;
    final detailsType = details?.runtimeType.toString() ?? 'null';
    final isDetailsMap = details is Map;

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
                    if (widget.networkInfo != null) ...[
                      _buildDebugRow(
                        theme,
                        'Provider',
                        widget.networkInfo!['provider']?.toString() ?? 'null',
                      ),
                      _buildDebugRow(
                        theme,
                        'Provider URL',
                        widget.networkInfo!['providerUrl']?.toString() ??
                            'null',
                      ),
                    ],
                    if (widget.errorMessage != null)
                      _buildDebugRow(theme, 'Error', widget.errorMessage!),
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

  void _showLocationExplanationDialog() {
    final details = widget.networkInfo?['ipDetails'];
    if (details is! Map) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationDetailsPage(
          details: Map<String, dynamic>.from(details),
          publicIP: widget.networkInfo?['publicIP'] ?? 'Unknown',
        ),
      ),
    );
  }

  void _showDebugInfoDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebugInfoPage(networkInfo: widget.networkInfo),
      ),
    );
  }
}
