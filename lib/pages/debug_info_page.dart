import 'package:flutter/material.dart';
import 'dart:convert';

class DebugInfoPage extends StatelessWidget {
  final Map<String, dynamic>? networkInfo;

  const DebugInfoPage({Key? key, required this.networkInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Information'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              // Could implement clipboard copy here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Debug info ready to copy'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Full Network Info',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _prettyPrintJson(networkInfo),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Stats',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow('Has Network Info', networkInfo != null),
                  _buildStatRow(
                    'Public IP Available',
                    networkInfo?['publicIP'] != null,
                  ),
                  _buildStatRow(
                    'Details Available',
                    networkInfo?['ipDetails'] is Map,
                  ),
                  _buildStatRow(
                    'Local Addresses',
                    networkInfo?['localAddresses'] is List,
                  ),
                  _buildStatRow('DNS Info', networkInfo?['dnsServers'] is List),
                  _buildStatRow(
                    'Privacy Assessment',
                    networkInfo?['privacyAssessment'] is Map,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  String _prettyPrintJson(dynamic json) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return json?.toString() ?? 'null';
    }
  }
}
