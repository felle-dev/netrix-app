import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ip_provider.dart';

class ProviderManager {
  static const String _providersKey = 'providers';
  static const String _selectedIndexKey = 'selected_provider_index';
  List<IPProvider> getDefaultProviders() {
    return [
      IPProvider(
        name: 'ip-api',
        ipUrl: 'http://ip-api.com/json/',
        detailsUrl: '',
        ipJsonKey: 'query',
      ),
    ];
  }

  Future<List<IPProvider>> loadProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final providersJson = prefs.getString(_providersKey);
    if (providersJson != null) {
      final List<dynamic> decoded = json.decode(providersJson);
      return decoded.map((e) => IPProvider.fromJson(e)).toList();
    } else {
      return getDefaultProviders();
    }
  }

  Future<int> loadSelectedProviderIndex(int providersLength) async {
    final prefs = await SharedPreferences.getInstance();
    int index = prefs.getInt(_selectedIndexKey) ?? 0;
    if (index >= providersLength) {
      index = 0;
    }
    return index;
  }

  Future<void> saveProviders(
    List<IPProvider> providers,
    int selectedIndex,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(providers.map((e) => e.toJson()).toList());
    await prefs.setString(_providersKey, encoded);
    await prefs.setInt(_selectedIndexKey, selectedIndex);
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_providersKey);
    await prefs.remove(_selectedIndexKey);
  }
}
