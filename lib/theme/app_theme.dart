import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeMode { tactical, desert, steel, dark, nightVision }

class AppTheme {
  static final Map<AppThemeMode, Map<String, Color>> palettes = {
    AppThemeMode.tactical: {
      'bg': const Color(0xFF0D1117), 'surface': const Color(0xFF161B22), 'surfaceLight': const Color(0xFF21262D),
      'primary': const Color(0xFF00E5FF), 'secondary': const Color(0xFF3FB950), 'text': const Color(0xFFE6EDF3),
      'border': const Color(0xFF30363D), 'warning': const Color(0xFFD29922), 'danger': const Color(0xFFDA3633),
    },
    AppThemeMode.desert: {
      'bg': const Color(0xFF2C241B), 'surface': const Color(0xFF3D3226), 'surfaceLight': const Color(0xFF4C3F30),
      'primary': const Color(0xFFD4A373), 'secondary': const Color(0xFF8B5A2B), 'text': const Color(0xFFFAEDCD),
      'border': const Color(0xFF5C4D3C), 'warning': const Color(0xFFE9C46A), 'danger': const Color(0xFFE76F51),
    },
    AppThemeMode.steel: {
      'bg': const Color(0xFF1A1D21), 'surface': const Color(0xFF2A2E33), 'surfaceLight': const Color(0xFF383E45),
      'primary': const Color(0xFFFF9800), 'secondary': const Color(0xFF9E9E9E), 'text': const Color(0xFFECEFF1),
      'border': const Color(0xFF424242), 'warning': const Color(0xFFFFB74D), 'danger': const Color(0xFFF44336),
    },
    AppThemeMode.dark: {
      'bg': const Color(0xFF0A1929), 'surface': const Color(0xFF132F4C), 'surfaceLight': const Color(0xFF1E4976),
      'primary': const Color(0xFF4CAF50), 'secondary': const Color(0xFF2196F3), 'text': const Color(0xFFB2BAC2),
      'border': const Color(0xFF1E4976), 'warning': const Color(0xFFFFC107), 'danger': const Color(0xFFE57373),
    },
    AppThemeMode.nightVision: {
      'bg': const Color(0xFF000000), 'surface': const Color(0xFF1A0000), 'surfaceLight': const Color(0xFF330000),
      'primary': const Color(0xFFFF0000), 'secondary': const Color(0xFFB30000), 'text': const Color(0xFFFF4D4D),
      'border': const Color(0xFF4D0000), 'warning': const Color(0xFFFF6600), 'danger': const Color(0xFF990000),
    },
  };

  static ThemeData getTheme(AppThemeMode mode) {
    final colors = palettes[mode]!;
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: colors['bg'],
      colorScheme: ColorScheme.dark(
        primary: colors['primary']!, secondary: colors['secondary']!,
        surface: colors['surface']!, onSurface: colors['text']!,
      ),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme).apply(bodyColor: colors['text'], displayColor: colors['text']),
      appBarTheme: AppBarTheme(
        backgroundColor: colors['surface'],
        titleTextStyle: GoogleFonts.cairo(color: colors['text'], fontSize: 20, fontWeight: FontWeight.bold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: colors['surface'],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors['border']!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors['primary']!, width: 2)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}