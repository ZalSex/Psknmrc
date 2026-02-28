import 'package:flutter/material.dart';

class AppTheme {
  static const darkBg   = Color(0xFF060D1A);
  static const cardBg   = Color(0xFF0D1F35);
  static const cardBg2  = Color(0xFF071525);
  static const purple   = Color(0xFF8B5CF6);
  static const purple2  = Color(0xFF6D28D9);
  static const green    = Color(0xFF10B981);
  static const red      = Color(0xFFEF4444);
  static const gold     = Color(0xFFFFD700);
  static const textMuted = Color(0xFF6B7280);

  static final cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [const Color(0xFF0D1F35), const Color(0xFF071525)],
  );

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    fontFamily: 'ShareTechMono',
    colorScheme: const ColorScheme.dark(
      primary: purple,
      secondary: green,
      surface: cardBg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
  );
}
