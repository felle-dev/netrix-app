import 'package:home_widget/home_widget.dart';
import '../controllers/network_service.dart';
import '../controllers/provider_manager.dart';
import '../utils/network_utils.dart';

/// Service to handle home screen widget updates
class HomeWidgetService {
  static const String _appGroupId =
      'com.example.netrix'; // Updated package name
  static const String _androidWidgetName = 'NetworkCheckerWidget';
  static const String _iOSWidgetName = 'NetworkCheckerWidget';

  final NetworkService _networkService = NetworkService();
  final ProviderManager _providerManager = ProviderManager();

  /// Initialize the home widget
  Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Show loading state on widget (NEW!)
  Future<void> showLoading() async {
    await HomeWidget.saveWidgetData<bool>('isLoading', true);
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
  }

  /// Hide loading state on widget (NEW!)
  Future<void> hideLoading() async {
    await HomeWidget.saveWidgetData<bool>('isLoading', false);
  }

  /// Update the widget with current network information
  Future<void> updateWidget() async {
    try {
      // Show loading first (NEW!)
      await showLoading();

      // Load providers
      final providers = await _providerManager.loadProviders();
      final selectedIndex = await _providerManager.loadSelectedProviderIndex(
        providers.length,
      );

      if (providers.isEmpty) {
        await _setErrorState('No providers available');
        return;
      }

      // Gather network info
      final provider = providers[selectedIndex];
      final info = await _networkService.gatherNetworkInfo(provider);

      // Extract data
      final details = info['ipDetails'];
      final publicIP = info['publicIP'] ?? 'Unknown';

      if (details is Map) {
        final country = details['country'] ?? 'Unknown';
        final city = details['city'] ?? 'Unknown';
        final isTor = details['isTor'] == true;
        final isp = details['isp'] ?? 'Unknown';

        // Hide loading (NEW!)
        await hideLoading();

        // Store data for widget
        await HomeWidget.saveWidgetData<String>('country', country);
        await HomeWidget.saveWidgetData<String>('city', city);
        await HomeWidget.saveWidgetData<String>('publicIP', publicIP);
        await HomeWidget.saveWidgetData<String>('isp', isp);
        await HomeWidget.saveWidgetData<bool>('isTor', isTor);
        await HomeWidget.saveWidgetData<String>(
          'flag',
          NetworkUtils.getCountryFlag(country),
        );
        await HomeWidget.saveWidgetData<String>(
          'lastUpdate',
          DateTime.now().toIso8601String(),
        );
        await HomeWidget.saveWidgetData<bool>('hasError', false);

        // Update widget
        await HomeWidget.updateWidget(
          androidName: _androidWidgetName,
          iOSName: _iOSWidgetName,
        );
      } else {
        await _setErrorState('Unable to fetch location data');
      }
    } catch (e) {
      await _setErrorState('Error: $e');
    }
  }

  Future<void> _setErrorState(String error) async {
    // Hide loading when showing error (NEW!)
    await hideLoading();

    await HomeWidget.saveWidgetData<bool>('hasError', true);
    await HomeWidget.saveWidgetData<String>('errorMessage', error);
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
  }

  /// Register background update callback
  static Future<void> registerBackgroundCallback() async {
    await HomeWidget.registerBackgroundCallback(backgroundCallback);
  }

  /// Background callback for widget refresh
  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    if (uri?.host == 'refresh') {
      final service = HomeWidgetService();
      await service.updateWidget();
    }
  }
}
