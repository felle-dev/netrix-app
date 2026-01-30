# Netrix - Network Privacy App

A Flutter application for monitoring network privacy with multiple IP provider support.

## 📁 Project Structure

```
lib/
├── main.dart                      # Entry point & main app structure
├── theme/
│   └── app_theme.dart            # Material 3 theme configuration
├── models/
│   └── ip_provider.dart          # IP Provider data model
└── tabs/
    ├── network_checker_tab.dart  # Privacy monitoring tab (fully functional)
    ├── app_tracker_tab.dart      # App internet tracker (placeholder)
    └── speed_test_tab.dart       # Speed test (placeholder)
```

## ✨ Features

### Network Checker Tab (Functional)
- **Privacy Score**: 0-100 scoring with visual indicator
- **Multiple IP Providers**: 7 default providers with automatic fallback
  - ipify
  - ipapi  
  - ip-api
  - seeip
  - myip
  - ipgeolocation
  - ifconfig
- **Custom Provider Support**: Add your own IP checker APIs
- **VPN/Tor Detection**: Automatically detects VPN and Tor usage
- **Local Network Info**: Shows all network interfaces
- **Privacy Tips**: Contextual recommendations based on assessment
- **State Persistence**: Tab state preserved with SharedPreferences

### App Tracker Tab (Placeholder)
- Coming soon: Per-app internet monitoring

### Speed Test Tab (Placeholder)
- Coming soon: Download/upload speed testing

## 🛠️ Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  dynamic_color: ^1.7.0
  http: ^1.1.0
  shared_preferences: ^2.2.2
```

## 🚀 Setup

1. Copy all files maintaining the directory structure
2. Run `flutter pub get`
3. Run the app with `flutter run`

## 📱 Key Classes

- **NetworkCheckerTab**: Main privacy monitoring functionality
- **AppTrackerTab**: Placeholder for app tracking
- **SpeedTestTab**: Placeholder for speed testing
- **IPProvider**: Model for IP checker service configuration
- **AppTheme**: Material 3 theme with dynamic color support

## 🔧 Custom IP Providers

Users can add custom IP providers through the app's Provider Settings:

1. Tap "Providers" button in Privacy tab
2. Tap "+" icon in Custom Providers section
3. Enter:
   - Provider Name
   - IP URL (API endpoint)
   - IP JSON Key (field name in response)
   - Details URL (optional, use `{ip}` placeholder)

## 📝 Notes

- State preservation via AutomaticKeepAliveClientMixin
- Provider fallback system for reliability
- SharedPreferences for caching and settings
- Material 3 design with dynamic theming