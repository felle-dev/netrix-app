import 'package:flutter/material.dart';

class IPDetailsCard extends StatelessWidget {
  final Map<String, dynamic>? networkInfo;

  const IPDetailsCard({Key? key, required this.networkInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = networkInfo?['ipDetails'];

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
          _buildHeader(theme, isTor),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          if (isTor)
            _buildTorDetails(theme, details)
          else
            _buildStandardDetails(theme, details),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isTor) {
    return Padding(
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
    );
  }

  Widget _buildTorDetails(ThemeData theme, Map details) {
    return Column(
      children: [..._buildDetailsList(theme, details, 'Exit Node ')],
    );
  }

  Widget _buildStandardDetails(ThemeData theme, Map details) {
    return Column(children: _buildDetailsList(theme, details, ''));
  }

  List<Widget> _buildDetailsList(ThemeData theme, Map details, String prefix) {
    final items = <Widget>[];
    final fields = [
      ('country', '${prefix}Country'),
      ('region', '${prefix}Region'),
      ('city', '${prefix}City'),
      ('isp', '${prefix}ISP'),
      if (prefix.isEmpty) ('timezone', 'Timezone'),
    ];

    for (var i = 0; i < fields.length; i++) {
      final field = fields[i];
      final value = details[field.$1];

      if (value != null && value != 'Unknown') {
        if (items.isNotEmpty) {
          items.add(
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: theme.colorScheme.outlineVariant,
            ),
          );
        }
        items.add(_buildDetailListTile(field.$2, value, theme));
      }
    }

    return items;
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
}
