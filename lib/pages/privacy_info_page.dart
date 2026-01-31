import 'package:flutter/material.dart';
import 'package:netrix/pages/isp_explanation_page.dart';

class PrivacyInfoPage extends StatelessWidget {
  const PrivacyInfoPage({Key? key}) : super(key: key);

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
            'All data is processed locally on your device. We do not:\n\n'
            '• Store your information on any servers\n'
            '• Share your data with third parties\n'
            '• Track your browsing history\n'
            '• Create user profiles\n\n'
            'The app only queries external IP services to retrieve your current network status.',
          ),
          const SizedBox(height: 20),
          Text(
            'Your Privacy',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This app is designed to help you understand your network privacy. '
            'All processing happens on your device, and no data is transmitted '
            'except to the IP provider services you select for checking your connection.',
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
            'The app connects to IP provider services (like ip-api.com) to retrieve '
            'your public IP information. These services may have their own privacy '
            'policies. No data is shared beyond what\'s necessary for the IP lookup.',
          ),
          const SizedBox(height: 24),
          _buildNavigationCard(context, theme),
        ],
      ),
    );
  }

  Widget _buildNavigationCard(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ISPExplanationPage()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.secondaryContainer,
              theme.colorScheme.secondaryContainer.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.secondary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.visibility_outlined,
                color: theme.colorScheme.secondary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learn About Privacy',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'What can your ISP see?',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer.withOpacity(
                        0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.colorScheme.secondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
