import 'package:flutter/material.dart';
import '../models/ip_provider.dart';
import '../controllers/network_service.dart';
import '../controllers/provider_manager.dart';
import '../widgets/ip_location_card.dart';
import '../widgets/ip_details_card.dart';
import '../widgets/local_addresses_card.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/privacy_banner.dart';
import '../pages/provider_settings_page.dart';

class NetworkCheckerTab extends StatefulWidget {
  const NetworkCheckerTab({Key? key}) : super(key: key);

  @override
  State<NetworkCheckerTab> createState() => _NetworkCheckerTabState();
}

class _NetworkCheckerTabState extends State<NetworkCheckerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final NetworkService _networkService = NetworkService();
  final ProviderManager _providerManager = ProviderManager();

  bool _isLoading = false;
  Map<String, dynamic>? _networkInfo;
  String? _errorMessage;
  int _selectedProviderIndex = 0;
  List<IPProvider> _providers = [];

  @override
  void initState() {
    super.initState();
    _loadProviders();
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

  Future<void> _checkNetwork() async {
    if (_providers.isEmpty) {
      setState(() {
        _errorMessage = 'No providers available';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = _providers[_selectedProviderIndex];
      final info = await _networkService.gatherNetworkInfo(provider);

      setState(() {
        _networkInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error gathering network info: $e';
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
