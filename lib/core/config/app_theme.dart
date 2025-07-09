import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_sizes.dart';

/// Application theme configuration
class AppTheme {
  AppTheme._();

  /// Main application theme
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: _createMaterialColor(AppColors.primary),
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'System', // Default system font
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.buttonText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.buttonText,
          fontSize: AppSizes.fontHeader,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.buttonText,
          padding: const EdgeInsets.symmetric(vertical: AppSizes.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: AppSizes.fontXLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: AppSizes.fontMedium,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        backgroundColor: AppColors.progressBarBackground,
        linearMinHeight: AppSizes.progressBarMinHeight,
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSmall),
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.iconColor,
        size: AppSizes.iconSmall,
      ),
    );
  }

  /// Create MaterialColor from Color
  static MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  // Predefined text styles
  static const TextStyle headerStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: AppSizes.fontTitle,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle titleStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: AppSizes.fontTitle,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: AppSizes.fontMedium,
  );

  static const TextStyle hintStyle = TextStyle(
    color: AppColors.textHint,
    fontSize: AppSizes.fontMedium,
  );

  static const TextStyle disabledStyle = TextStyle(
    color: AppColors.textDisabled,
    fontSize: AppSizes.fontMedium,
  );
}