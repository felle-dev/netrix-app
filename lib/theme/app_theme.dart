import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const String primaryFont = 'Outfit';
  static const String displayFont = 'NoyhR';

  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(fontFamily: displayFont),
      displayMedium: TextStyle(fontFamily: displayFont),
      displaySmall: TextStyle(fontFamily: displayFont),
      headlineLarge: TextStyle(fontFamily: displayFont),
      headlineMedium: TextStyle(fontFamily: displayFont),
      headlineSmall: TextStyle(fontFamily: displayFont),
      titleLarge: TextStyle(fontFamily: displayFont),
    );
  }

  static ThemeData lightTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: primaryFont,
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        // REMOVED: systemOverlayStyle - this is handled dynamically in main.dart now
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ThemeData darkTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: primaryFont,
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        // REMOVED: systemOverlayStyle - this is handled dynamically in main.dart now
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ColorScheme getDefaultLightColorScheme() {
    return ColorScheme.fromSeed(seedColor: Colors.purple);
  }

  static ColorScheme getDefaultDarkColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: Colors.purple,
      brightness: Brightness.dark,
    );
  }
}
