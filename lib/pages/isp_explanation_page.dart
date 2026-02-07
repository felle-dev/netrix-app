import 'package:flutter/material.dart';

class ISPExplanationPage extends StatelessWidget {
  const ISPExplanationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Levels')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Understanding Your Digital Privacy',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your internet service provider (ISP) can see different amounts of your online activity depending on how you connect.',
          ),
          const SizedBox(height: 20),

          Text(
            'No Protection',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your internet provider sees all your online activity in detail.\n\n'
            'Your ISP can see:\n'
            '• Every website you visit\n'
            '• All search queries\n'
            '• Your exact location\n'
            '• Everything you download\n'
            '• Time spent on each site',
          ),
          const SizedBox(height: 20),

          Text(
            'VPN Protection',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your internet provider only sees encrypted data flowing to the VPN server.\n\n'
            'Your ISP can see:\n'
            '• You are using a VPN\n'
            '• Amount of data transferred\n'
            '• Connection timing\n\n'
            'Your ISP cannot see:\n'
            '• Which websites you visit\n'
            '• What you search for\n'
            '• Content you view or download',
          ),
          const SizedBox(height: 20),

          Text(
            'Tor Protection',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your internet provider only knows you\'re using Tor, nothing else.\n\n'
            'Your ISP can see:\n'
            '• You are using Tor\n'
            '• Encrypted traffic volume\n\n'
            'Your ISP cannot see:\n'
            '• Your destination websites\n'
            '• Your online activities\n'
            '• Any of your content',
          ),
          const SizedBox(height: 20),

          Text(
            'Mobile Network Privacy',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mobile operators (Indosat, Telkomsel, Three, XL) can see everything your regular ISP sees, plus:\n\n'
            '• Your phone number and device ID\n'
            '• Your physical location\n'
            '• Which cell towers you connect to\n'
            '• Call and SMS records\n\n'
            'Note: VPN hides your browsing but not your location.',
          ),
          const SizedBox(height: 20),

          Text(
            'Cell Tower Tracking',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your mobile provider knows your approximate location based on which cell tower your phone connects to. This tracking works even when you\'re not using data, just by having your phone turned on.',
          ),
          const SizedBox(height: 20),

          Text(
            'What This App Shows',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This app displays what websites and online services can see about you: your public IP address and general location.\n\n'
            'This is NOT what your ISP sees. Your ISP can see much more detailed information about your internet usage.',
          ),
        ],
      ),
    );
  }
}
