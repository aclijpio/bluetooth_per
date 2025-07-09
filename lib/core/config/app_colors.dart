import 'package:flutter/material.dart';

/// Application color palette configuration
class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF0B78CC);
  static const Color primaryLight = Color(0xFF2E6FED);
  static const Color primaryBackground = Color(0xFFC0D5F2);

  // Text Colors
  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF424242);
  static const Color textHint = Color(0xFF5F5F5F);
  static const Color textTertiary = Color(0xFF666666);
  static const Color textDisabled = Color(0xFF484848);

  // Background Colors
  static const Color background = Colors.white;
  static const Color cardBackground = Color(0xFFE7F2FA);
  static const Color progressBarBackground = Colors.grey; // Colors.grey[300]

  // Status Colors
  static const Color error = Colors.red;
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color info = Colors.blue;

  // Component specific colors
  static const Color appBarBackground = primary;
  static const Color buttonText = Colors.white;
  static const Color iconColor = primary;
  static const Color disabledIconColor = Colors.grey;
}