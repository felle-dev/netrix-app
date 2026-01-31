import 'package:home_widget/home_widget.dart';
import '../controllers/network_service.dart';
import '../controllers/provider_manager.dart';
import '../utils/network_utils.dart';

class HomeWidgetService {
  static const String _appGroupId = 'com.example.netrix';
  static const String _androidWidgetName = 'NetworkCheckerWidget';
  static const String _iOSWidgetName = 'NetworkCheckerWidget';

  final NetworkService _networkService = NetworkService();
  final ProviderManager _providerManager = ProviderManager();

  Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  Future<void> updateLoadingState(
    int percentage,
    String status,
    String debug,
  ) async {
    await HomeWidget.saveWidgetData<bool>('isLoading', true);
    await HomeWidget.saveWidgetData<int>('loadingPercentage', percentage);
    await HomeWidget.saveWidgetData<String>('loadingStatus', status);
    await HomeWidget.saveWidgetData<String>('loadingDebug', debug);
    await HomeWidget.saveWidgetData<String>(
      'loadingStartTime',
      DateTime.now().toIso8601String(),
    );
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
    print('Widget loading: $percentage% - $status - $debug');
  }

  Future<void> showLoading() async {
    await updateLoadingState(0, 'Starting...', 'Widget refresh triggered');
  }

  Future<void> hideLoading() async {
    await HomeWidget.saveWidgetData<bool>('isLoading', false);
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
    print('Widget loading hidden');
  }

  Future<void> updateWidget() async {
    try {
      await updateLoadingState(
        10,
        'Loading providers',
        'Checking saved providers',
      );

      final providers = await _providerManager.loadProviders();
      final selectedIndex = await _providerManager.loadSelectedProviderIndex(
        providers.length,
      );

      if (providers.isEmpty) {
        await _setErrorState('No providers available');
        return;
      }

      await updateLoadingState(
        20,
        'Provider loaded',
        'Using: ${providers[selectedIndex].name}',
      );

      final provider = providers[selectedIndex];

      // Fixed: Use ipUrl instead of url
      await updateLoadingState(
        30,
        'Fetching IP',
        'Contacting: ${provider.ipUrl}',
      );

      final info = await _networkService.gatherNetworkInfo(provider);

      await updateLoadingState(60, 'Processing data', 'Got network response');

      final details = info['ipDetails'];
      final publicIP = info['publicIP'] ?? 'Unknown';

      if (details is Map) {
        final country = details['country'] ?? 'Unknown';
        final city = details['city'] ?? 'Unknown';
        final isTor = details['isTor'] == true;
        final isp = details['isp'] ?? 'Unknown';

        await updateLoadingState(80, 'Saving data', 'Country: $country');

        await HomeWidget.saveWidgetData<bool>('isLoading', false);
        await HomeWidget.saveWidgetData<bool>('hasError', false);
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

        await updateLoadingState(100, 'Complete!', 'Widget updated');

        await HomeWidget.updateWidget(
          androidName: _androidWidgetName,
          iOSName: _iOSWidgetName,
        );

        print('Widget update successful: $country, $city');
      } else {
        await _setErrorState('Invalid data format');
      }
    } catch (e) {
      print('Widget update error: $e');
      await _setErrorState('Error: $e');
    }
  }

  Future<void> quickUpdateWidget(Map<String, dynamic> networkInfo) async {
    try {
      await updateLoadingState(50, 'Quick update', 'Using cached data');

      final details = networkInfo['ipDetails'];
      final publicIP = networkInfo['publicIP'] ?? 'Unknown';

      if (details is Map) {
        final country = details['country'] ?? 'Unknown';
        final city = details['city'] ?? 'Unknown';
        final isTor = details['isTor'] == true;
        final isp = details['isp'] ?? 'Unknown';

        await HomeWidget.saveWidgetData<bool>('isLoading', false);
        await HomeWidget.saveWidgetData<bool>('hasError', false);
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

        await HomeWidget.updateWidget(
          androidName: _androidWidgetName,
          iOSName: _iOSWidgetName,
        );

        print('Widget quick update successful');
      }
    } catch (e) {
      print('Widget quick update error: $e');
    }
  }

  Future<void> _setErrorState(String error) async {
    await HomeWidget.saveWidgetData<bool>('isLoading', false);
    await HomeWidget.saveWidgetData<bool>('hasError', true);
    await HomeWidget.saveWidgetData<String>('errorMessage', error);
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
    print('Widget error: $error');
  }

  static Future<void> registerBackgroundCallback() async {
    await HomeWidget.registerBackgroundCallback(backgroundCallback);
  }

  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    print('Widget background callback: ${uri?.toString()}');

    if (uri?.host == 'refresh') {
      try {
        final service = HomeWidgetService();
        await service.updateLoadingState(5, 'Background', 'Callback triggered');
        await service.updateWidget();
      } catch (e) {
        print('Background update error: $e');
        await HomeWidget.saveWidgetData<bool>('isLoading', false);
        await HomeWidget.saveWidgetData<bool>('hasError', true);
        await HomeWidget.saveWidgetData<String>(
          'errorMessage',
          'Background error: $e',
        );
        await HomeWidget.updateWidget(
          androidName: 'NetworkCheckerWidget',
          iOSName: 'NetworkCheckerWidget',
        );
      }
    }
  }
}
