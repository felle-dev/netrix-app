import 'package:flutter/material.dart';
import 'package:netrix/pages/provider_settings_page.dart';
import 'package:home_widget/home_widget.dart';
import 'package:netrix/widgets/map_preview_card.dart';
import '../models/ip_provider.dart';
import '../controllers/network_service.dart';
import '../controllers/provider_manager.dart';
import '../services/home_widget_service.dart';
import '../widgets/ip_location_card.dart';
import '../widgets/ip_details_card.dart';
import '../widgets/local_addresses_card.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/privacy_banner.dart';
import '../widgets/network_loading_indicator.dart';
import '../pages/fullscreen_map_page.dart';

class NetworkCheckerTab extends StatefulWidget {
  const NetworkCheckerTab({Key? key}) : super(key: key);

  @override
  State<NetworkCheckerTab> createState() => NetworkCheckerTabState();
}

class NetworkCheckerTabState extends State<NetworkCheckerTab>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  final NetworkService _networkService = NetworkService();
  final ProviderManager _providerManager = ProviderManager();
  final HomeWidgetService _widgetService = HomeWidgetService();

  bool _isLoading = false;
  double _loadingProgress = 0.0;
  String _loadingStatus = 'Initializing...';
  Map<String, dynamic>? _networkInfo;
  String? _errorMessage;
  int _selectedProviderIndex = 0;
  List<IPProvider> _providers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProviders();
    print('NetworkCheckerTab initialized');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('App lifecycle state: $state');
    if (state == AppLifecycleState.resumed) {
      _checkForPendingWidgetRefresh();
    }
  }

  Future<void> _checkForPendingWidgetRefresh() async {
    try {
      final shouldRefresh = await HomeWidget.getWidgetData<bool>(
        'shouldRefresh',
      );
      print('Should refresh from widget: $shouldRefresh');
      if (shouldRefresh == true) {
        // Clear the flag
        await HomeWidget.saveWidgetData<bool>('shouldRefresh', false);
        print('Starting widget-triggered refresh');
        // Small delay to ensure app is fully visible
        await Future.delayed(const Duration(milliseconds: 300));
        _checkNetwork();
      }
    } catch (e) {
      print('Error checking pending refresh: $e');
    }
  }

  Future<void> _loadProviders() async {
    try {
      final providers = await _providerManager.loadProviders();
      final selectedIndex = await _providerManager.loadSelectedProviderIndex(
        providers.length,
      );

      setState(() {
        _providers = providers;
        _selectedProviderIndex = selectedIndex;
      });

      _checkNetwork();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading providers: $e';
      });
    }
  }

  Future<void> _saveProviders() async {
    await _providerManager.saveProviders(_providers, _selectedProviderIndex);
  }

  Future<void> refreshNetwork() async {
    return _checkNetwork();
  }

  Future<void> _checkNetwork() async {
    print('=== Starting network check ===');

    if (_providers.isEmpty) {
      setState(() {
        _errorMessage = 'No providers available';
        _isLoading = false;
      });
      await _widgetService.updateLoadingState(0, 'Error', 'No providers');
      await _widgetService.hideLoading();
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingProgress = 0.0;
      _loadingStatus = 'Preparing network check...';
      _errorMessage = null;
    });

    await _widgetService.updateLoadingState(
      5,
      'Started',
      'App initiated check',
    );

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() {
        _loadingProgress = 0.1;
        _loadingStatus = 'Selecting provider...';
      });
      await _widgetService.updateLoadingState(
        10,
        'Provider',
        'Loading provider list',
      );

      final provider = _providers[_selectedProviderIndex];
      print('Using provider: ${provider.name}');

      setState(() {
        _loadingProgress = 0.2;
        _loadingStatus = 'Fetching public IP...';
      });
      await _widgetService.updateLoadingState(
        20,
        'Fetching IP',
        'Provider: ${provider.name}',
      );

      final infoFuture = _networkService.gatherNetworkInfo(provider);
      _simulateProgress();

      print('Waiting for network info...');
      final info = await infoFuture;
      print('Got network info: ${info.keys}');

      setState(() {
        _loadingProgress = 0.8;
        _loadingStatus = 'Processing location data...';
      });
      await _widgetService.updateLoadingState(
        80,
        'Processing',
        'Parsing response',
      );

      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _loadingProgress = 0.9;
        _loadingStatus = 'Updating widget...';
      });

      print('Quick updating widget...');
      await _widgetService.quickUpdateWidget(info);

      setState(() {
        _loadingProgress = 1.0;
        _loadingStatus = 'Complete!';
      });

      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _networkInfo = info;
        _isLoading = false;
      });

      print('=== Network check complete ===');
    } catch (e) {
      print('ERROR in network check: $e');
      await _widgetService.updateLoadingState(0, 'Error', e.toString());
      await _widgetService.hideLoading();

      setState(() {
        _errorMessage = 'Error gathering network info: $e';
        _isLoading = false;
        _loadingProgress = 0.0;
      });
    }
  }

  Future<void> _simulateProgress() async {
    final steps = [0.3, 0.4, 0.5, 0.6, 0.7];
    final statuses = [
      'Checking network interfaces...',
      'Detecting VPN/Tor...',
      'Analyzing privacy status...',
      'Checking DNS servers...',
      'Finalizing results...',
    ];
    final widgetStatuses = [
      'Network check',
      'VPN/Tor detect',
      'Privacy analysis',
      'DNS check',
      'Finalizing',
    ];

    for (int i = 0; i < steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!_isLoading) break;
      setState(() {
        _loadingProgress = steps[i];
        _loadingStatus = statuses[i];
      });
      await _widgetService.updateLoadingState(
        (steps[i] * 100).toInt(),
        widgetStatuses[i],
        'Step ${i + 1}/5',
      );
    }
  }

  void _showProviderSettingsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProviderSettingsPage(
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
              _providers = _providerManager.getDefaultProviders();
              _selectedProviderIndex = 0;
            });
            await _saveProviders();
            _checkNetwork();
          },
        ),
      ),
    );
  }

  Widget _buildMapWidget(ThemeData theme) {
    if (_networkInfo == null) return const SizedBox.shrink();

    final ipDetails = _networkInfo!['ipDetails'];
    if (ipDetails == null) return const SizedBox.shrink();

    final lat = ipDetails['lat'] ?? ipDetails['latitude'];
    final lon = ipDetails['lon'] ?? ipDetails['longitude'];
    final isTor = ipDetails['isTor'] == true;
    final country = ipDetails['country'] ?? 'Unknown';

    return MapPreviewWidget(
      latitude: lat != null ? double.tryParse(lat.toString()) : null,
      longitude: lon != null ? double.tryParse(lon.toString()) : null,
      isTor: isTor,
      country: country,
      onTap: () {
        if (lat != null && lon != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenMapPage(
                lat: double.parse(lat.toString()),
                lon: double.parse(lon.toString()),
                isTor: isTor,
                country: country,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        body: NetworkLoadingIndicator(
          progress: _loadingProgress,
          statusText: _loadingStatus,
        ),
      );
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
          IPLocationFocusCard(
            networkInfo: _networkInfo,
            errorMessage: _errorMessage,
          ),
          const SizedBox(height: 16),
          _buildMapWidget(theme),
          const SizedBox(height: 16),
          IPDetailsCard(networkInfo: _networkInfo),
          const SizedBox(height: 16),
          LocalAddressesCard(networkInfo: _networkInfo),
          const SizedBox(height: 16),
          ConnectionStatusCard(
            networkInfo: _networkInfo,
            providers: _providers,
            selectedProviderIndex: _selectedProviderIndex,
          ),
          const SizedBox(height: 16),
          const PrivacyBanner(),
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
}
