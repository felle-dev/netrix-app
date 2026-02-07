import 'package:flutter/material.dart';

class LocalAddressExplanationPage extends StatelessWidget {
  const LocalAddressExplanationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Local Network Addresses')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'What are local addresses?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Local network addresses are IP addresses assigned to your device within your local network (home, office, etc.). '
            'These are different from your public IP address that websites see.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildSection(
            theme,
            'IPv4 vs IPv6',
            'IPv4 addresses look like 192.168.1.100, while IPv6 addresses are longer and look like fe80::1234:5678. '
                'Both serve the same purpose but IPv6 is the newer standard.',
          ),
          _buildSection(
            theme,
            'Network Interfaces',
            'Your device can have multiple network interfaces (WiFi, Ethernet, VPN, etc.), and each can have its own local address. '
                'This is why you might see multiple addresses listed.',
          ),
          _buildSection(
            theme,
            'Privacy Note',
            'Local addresses are only visible within your local network. They are not exposed to the internet. '
                'Websites can only see your public IP address.',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: If you see an IPv6 leak warning, consider disabling IPv6 or ensuring your VPN supports it.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(content, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
