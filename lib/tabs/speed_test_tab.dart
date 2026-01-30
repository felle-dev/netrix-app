import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SpeedTestTab extends StatefulWidget {
  const SpeedTestTab({Key? key}) : super(key: key);

  @override
  State<SpeedTestTab> createState() => _SpeedTestTabState();
}

class _SpeedTestTabState extends State<SpeedTestTab>
    with SingleTickerProviderStateMixin {
  TestState _testState = TestState.idle;
  double _downloadSpeed = 0.0;
  double _uploadSpeed = 0.0;
  double _progress = 0.0;
  List<SpeedTestResult> _history = [];

  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
    _loadHistory();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('speed_test_history');
    if (historyJson != null) {
      final List<dynamic> decoded = jsonDecode(historyJson);
      setState(() {
        _history = decoded
            .map((item) => SpeedTestResult.fromJson(item))
            .toList();
      });
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = jsonEncode(
      _history.map((item) => item.toJson()).toList(),
    );
    await prefs.setString('speed_test_history', historyJson);
  }

  Future<void> _runSpeedTest() async {
    setState(() {
      _testState = TestState.testing;
      _downloadSpeed = 0.0;
      _uploadSpeed = 0.0;
      _progress = 0.0;
    });

    _animationController.repeat();

    try {
      // Test download
      setState(() => _testState = TestState.download);
      await _testDownload();
      setState(() => _progress = 0.5);

      // Test upload
      setState(() => _testState = TestState.upload);
      await _testUpload();
      setState(() => _progress = 1.0);

      // Save result
      _saveResult();

      setState(() => _testState = TestState.complete);
    } catch (e) {
      setState(() => _testState = TestState.error);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Test failed: ${e.toString()}')));
      }
    } finally {
      _animationController.stop();
      _animationController.reset();
    }
  }

  Future<void> _testDownload() async {
    // Using a test file from a CDN for download speed test
    // This is a ~10MB file for testing
    const testUrl = 'https://speed.cloudflare.com/__down?bytes=10000000';

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 30));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes.length;
        final seconds = stopwatch.elapsedMilliseconds / 1000;
        final megabits = (bytes * 8) / 1000000;

        setState(() {
          _downloadSpeed = megabits / seconds;
        });
      }
    } catch (e) {
      // Fallback to a smaller test if the large one fails
      await _testDownloadFallback();
    }
  }

  Future<void> _testDownloadFallback() async {
    // Smaller test file as fallback
    const testUrl = 'https://speed.cloudflare.com/__down?bytes=1000000';

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes.length;
        final seconds = stopwatch.elapsedMilliseconds / 1000;
        final megabits = (bytes * 8) / 1000000;

        setState(() {
          _downloadSpeed = megabits / seconds;
        });
      }
    } catch (e) {
      setState(() {
        _downloadSpeed = 0.0;
      });
    }
  }

  Future<void> _testUpload() async {
    // Generate random data for upload test
    final random = Random();
    final data = List<int>.generate(1000000, (_) => random.nextInt(256));

    try {
      final stopwatch = Stopwatch()..start();
      await http
          .post(Uri.parse('https://speed.cloudflare.com/__up'), body: data)
          .timeout(const Duration(seconds: 30));
      stopwatch.stop();

      final bytes = data.length;
      final seconds = stopwatch.elapsedMilliseconds / 1000;
      final megabits = (bytes * 8) / 1000000;

      setState(() {
        _uploadSpeed = megabits / seconds;
      });
    } catch (e) {
      setState(() {
        _uploadSpeed = 0.0;
      });
    }
  }

  void _saveResult() {
    final result = SpeedTestResult(
      downloadSpeed: _downloadSpeed,
      uploadSpeed: _uploadSpeed,
      timestamp: DateTime.now(),
    );

    setState(() {
      _history.insert(0, result);
      if (_history.length > 20) {
        _history = _history.sublist(0, 20);
      }
    });

    _saveHistory();
  }

  void _resetTest() {
    setState(() {
      _testState = TestState.idle;
      _downloadSpeed = 0.0;
      _uploadSpeed = 0.0;
      _progress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildTestCard(theme),
        const SizedBox(height: 0),
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildHistoryCard(theme),
        ],
        const SizedBox(height: 16),
        _buildPrivacyBanner(theme),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildPrivacyBanner(ThemeData theme) {
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
          onTap: _showPrivacyInfoBottomSheet,
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

  void _showPrivacyInfoBottomSheet() {
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
                    '• Download and upload speed measurements\n'
                    '• Test timestamps\n'
                    '• Test history (stored locally only)',
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
                    '• Test history is saved locally on your device\n'
                    '• No data is sent to our servers\n'
                    '• No tracking or analytics\n'
                    '• No third-party data sharing',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Third-Party Service',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We use Cloudflare\'s speed test service to measure your connection speed:\n\n'
                    '• speed.cloudflare.com',
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
                            'Cloudflare may log your IP address and connection data according to their privacy policy.',
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
                    '• Tests run only when you manually start them\n'
                    '• You can clear your test history anytime\n'
                    '• All requests are made directly from your device\n'
                    '• No background or automatic testing',
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

  Widget _buildTestCard(ThemeData theme) {
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
                  Icons.speed_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Internet Speed Test',
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
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                _buildSpeedMeter(theme),
                const SizedBox(height: 32),
                _buildSpeedStats(theme),
                const SizedBox(height: 24),
                _buildActionButton(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedMeter(ThemeData theme) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _testState == TestState.testing
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withOpacity(0.3),
              width: 12,
            ),
          ),
          child: Stack(
            children: [
              if (_testState == TestState.testing)
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              Center(
                child: Transform.rotate(
                  angle: _testState == TestState.testing
                      ? _rotationAnimation.value
                      : 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getStateIcon(),
                        size: 60,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getStateText(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (_testState == TestState.testing)
                        Text(
                          _getCurrentTestText(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpeedStats(ThemeData theme) {
    if (_testState == TestState.idle) {
      return Column(
        children: [
          Text(
            'Speed Test',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Measure your internet connection speed with download and upload tests.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              theme,
              'Download',
              '${_downloadSpeed.toStringAsFixed(1)} Mbps',
              Icons.download_outlined,
            ),
            _buildStatItem(
              theme,
              'Upload',
              '${_uploadSpeed.toStringAsFixed(1)} Mbps',
              Icons.upload_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(ThemeData theme) {
    if (_testState == TestState.testing) {
      return const SizedBox.shrink();
    }

    if (_testState == TestState.complete || _testState == TestState.error) {
      return FilledButton.icon(
        onPressed: _resetTest,
        icon: const Icon(Icons.refresh),
        label: const Text('Test Again'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      );
    } else if (_testState == TestState.testing ||
        _testState == TestState.download ||
        _testState == TestState.upload) {
      return const SizedBox.shrink();
    }

    return FilledButton.icon(
      onPressed: _runSpeedTest,
      icon: const Icon(Icons.play_arrow),
      label: const Text('Start Test'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    );
  }

  Widget _buildHistoryCard(ThemeData theme) {
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
                Icon(Icons.history, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recent Tests',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (_history.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _history.clear();
                      });
                      _saveHistory();
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ..._history.take(5).map((result) => _buildHistoryItem(theme, result)),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(ThemeData theme, SpeedTestResult result) {
    final formattedDate = _formatDate(result.timestamp);

    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.speed,
              color: theme.colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.download, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                '${result.downloadSpeed.toStringAsFixed(1)} Mbps',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Icon(Icons.upload, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                '${result.uploadSpeed.toStringAsFixed(1)} Mbps',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          subtitle: Text(
            formattedDate,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (result != _history.last)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: theme.colorScheme.outlineVariant,
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getStateIcon() {
    switch (_testState) {
      case TestState.idle:
        return Icons.network_check_outlined;
      case TestState.testing:
      case TestState.download:
      case TestState.upload:
        return Icons.speed;
      case TestState.complete:
        return Icons.check_circle_outline;
      case TestState.error:
        return Icons.error_outline;
    }
  }

  String _getStateText() {
    switch (_testState) {
      case TestState.idle:
        return 'Ready';
      case TestState.testing:
      case TestState.download:
      case TestState.upload:
        return 'Testing...';
      case TestState.complete:
        return 'Complete';
      case TestState.error:
        return 'Error';
    }
  }

  String _getCurrentTestText() {
    switch (_testState) {
      case TestState.download:
        return 'Testing download...';
      case TestState.upload:
        return 'Testing upload...';
      default:
        return '';
    }
  }
}

enum TestState { idle, testing, download, upload, complete, error }

class SpeedTestResult {
  final double downloadSpeed;
  final double uploadSpeed;
  final DateTime timestamp;

  SpeedTestResult({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'downloadSpeed': downloadSpeed,
    'uploadSpeed': uploadSpeed,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SpeedTestResult.fromJson(Map<String, dynamic> json) =>
      SpeedTestResult(
        downloadSpeed: json['downloadSpeed'],
        uploadSpeed: json['uploadSpeed'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}
