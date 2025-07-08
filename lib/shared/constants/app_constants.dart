import 'package:flutter/material.dart';

class AppConstants {
  // Colors
  static const Color primaryColor = Color(0xFF0B78CC);
  static const Color backgroundColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF222222);
  static const Color textSecondaryColor = Color(0xFF5F5F5F);
  static const Color successColor = Colors.green;
  static const Color errorColor = Colors.red;
  static const Color warningColor = Colors.orange;

  // Sizes
  static const double borderRadius = 12.0;
  static const double buttonHeight = 56.0;
  static const double cardElevation = 2.0;
  static const double standardPadding = 20.0;
  static const double smallPadding = 12.0;
  static const double largePadding = 24.0;

  // Text Styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimaryColor,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondaryColor,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Bluetooth
  static const String deviceNameFilter = 'Quantor';
  static const Duration scanTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 15);

  // File Operations
  static const String archivesDirName = '_Архив КВАНТОР';
  static const String dbExtension = '.db';
  static const String notExportedSuffix = '_NEED_EXPORT';

  // Network
  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
}
