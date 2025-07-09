import 'package:flutter/material.dart';

class AppConfig {
  static const String archivesDirName = '_Архив КВАНТОР';
  static const String appName = 'Transfer_QT';

  static const String serverBaseUrl = 'http://tms.quantor-t.ru:8080';
  static const String webUUID = "595a31f7-ad09-43ff-9a04-1c29bfe795cb";

  static const String notExportedSuffix = '_NEED_EXPORT';
  static const String dbExtension = '.db';

  /// Таймаут для стандартного веб-запроса
  static const Duration webRequestTimeout = Duration(seconds: 15);

  /// Таймаут для долгих запросов (например, загрузка больших файлов)
  static const Duration longRequestTimeout = Duration(seconds: 100);

  /// Короткая задержка для UI (например, перед переходом на другой экран)
  static const Duration uiShortDelay = Duration(seconds: 1);

  /// Задержка перед повторной попыткой подключения к серверу
  static const Duration serverConnectionRetryDelay = Duration(seconds: 2);

  /// Базовая задержка для экспоненциальной выдержки при подключении к серверу
  static const Duration serverConnectionExponentialBackoffBase =
      Duration(seconds: 1);

  /// Таймаут на поиск блютуз устройств
  static const Duration bluetoothSearchDelay = Duration(seconds: 1);

  /// Таймаут для выполнения шага в сценарии работы с устройством
  static const Duration deviceFlowTimeout = Duration(seconds: 30);

  /// Таймаут для получения готового архива
  static const Duration readyArchiveTimeout = Duration(seconds: 10);

  /// Длительность попытки выполнения операции
  static const Duration attemptDuration = Duration(seconds: 50);

  /// Таймаут выполнения блютуз команды
  static const Duration bluetoothCommandTimeout = Duration(seconds: 15);

  static const Duration shortDelay = Duration(milliseconds: 500);

  static const Duration veryShortDelay = Duration(milliseconds: 100);

  static const Duration dbUpdateMaxAge = Duration(hours: 24);

  // --- Цветовая палитра ---
  static const Color primaryColor = Color(0xFF0B78CC);
  static const Color secondaryColor = Color(0xFF2E6FED);
  static const Color primaryTextColor = Color(0xFF222222);
  static const Color secondaryTextColor = Color(0xFF424242);
  static const Color tertiaryTextColor = Color(0xFF5F5F5F);
  static const Color lightTextColor = Color(0xFF666666);
  static const Color tableTextColor = Color(0xFF484848);
  static const Color cardBackgroundColor = Color(0xFFE7F2FA);
  static const Color progressBackgroundColor = Color(0xFFC0D5F2);
  static const Color errorColor = Colors.red;

  // --- Размеры и отступы ---
  static const double spacingExtraSmall = 8.0;
  static const double spacingSmall = 12.0;
  static const double spacingMedium = 20.0;
  static const double spacingLarge = 40.0;

  static final BorderRadius mediumBorderRadius = BorderRadius.circular(18);
  static final BorderRadius largeBorderRadius = BorderRadius.circular(27);
  static final BorderRadius dialogBorderRadius = BorderRadius.circular(20);

  static const EdgeInsets screenPadding = EdgeInsets.all(20);

  static const Color progressBarColor = primaryColor;
  static final Color progressBarBackgroundColor = Colors.grey[300]!;
  static const double progressBarHeight = 16.0;
  static final BorderRadius progressBarBorderRadius = BorderRadius.circular(10);
  static const double progressBarSpacing = 12.0;
  static const double progressBarPercentWidth = 45.0;
  static const TextStyle progressBarTextStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: secondaryTextColor,
  );

  static const TextStyle titleStyle = TextStyle(
    color: primaryTextColor,
    fontSize: 24,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle screenTitleStyle = TextStyle(
    color: primaryTextColor,
    fontSize: 24,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle subtitleStyle = TextStyle(
    color: tertiaryTextColor,
    fontSize: 24,
  );

  static const TextStyle bodyTextStyle = TextStyle(
    color: lightTextColor,
    fontSize: 16,
  );

  static const TextStyle bodySecondaryTextStyle = TextStyle(
    color: secondaryTextColor,
    fontSize: 16,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    color: primaryColor,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static String notExportedFileName(String deviceName, String fileName) {
    return '${deviceName}_${fileName}${notExportedSuffix}${dbExtension}';
  }

  static String exportedFileName(String deviceName, String fileName) {
    return '${deviceName}_${fileName}${dbExtension}';
  }
}
