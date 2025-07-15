import 'package:flutter/material.dart';
import 'package:logger/web.dart';

class AppConfig {
  static const String archivesDirName = '_Архив КВАНТОР';
  static const String appName = 'Transfer_QT';
  static final RegExp bluetoothServerRegExp =
      RegExp(r'^Quantor (?:[A-Z]|\d)+$', caseSensitive: false);

  static const String serverBaseUrl = 'http://tms.quantor-t.ru:8080';
  static const String webUUID = "595a31f7-ad09-43ff-9a04-1c29bfe795cb";

  static const String notExportedSuffix = '_NEED_EXPORT';
  static const String dbExtension = '.db';

  // --- Конфигурация логирования ---
  static const String logsDirName = 'quantorLogs';
  static const String logFileExtension = '.log';
  static const int maxLogFileSize = 3 * 1024 * 1024; // 3 MB
  static const int maxLogFilesCount = 5; // Максимум файлов логов
  static const Duration logRotationCheckInterval = Duration(hours: 2);
  static const Duration maxLogAge =
      Duration(days: 3); // Удалять логи старше 3 дней

  // --- Конфигурация отправки логов ---
  static const String supportEmail = 'teinpoint@gmail.com';
  static const String logEmailSubject = 'Логи Bluetooth Per';
  static const String logEmailBodyPrefix = 'Логи приложения Bluetooth Per:\n\n';
  static const int maxMailtoContentLength = 2000; // Лимит для mailto
  static const String mailtoTruncationMessage =
      '\n\n... (логи обрезаны из-за ограничений mailto)';

  // --- SMTP конфигурация ---
  // Для Gmail:
  // 2. Создать пароль приложения: https://myaccount.google.com/apppasswords
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 587;
  static const String senderEmail =
      'aclijpio@gmail.com';
  static const String senderPassword =
      'ljld nvsf ufop qrht';
  static const String senderName = 'Trasnfer-QT ';

  // Значения
  static const String appVersion = '1.0.8';
  static const String developerName = 'КВАНТОР';

  // Кнопки и действия
  static const String sendLogsToDevsTitle = 'Отправить логи разработчикам';
  static const String sendLogsToDevsSubtitle =
      'Отправка файлов логов для диагностики проблем';
  static const String sendLogsDialogTitle = 'Отправка логов';
  static const String sendLogsDialogContent =
      'Логи содержат информацию о работе приложения и могут помочь в диагностике проблем.';
  static const String sendLogsDialogPrivacy =
      'Логи не содержат персональных данных или содержимого файлов.';
  static const String cancelButtonText = 'Отмена';
  static const String sendButtonText = 'Отправить';

  static const Duration webRequestTimeout = Duration(seconds: 15);

  static const Duration longRequestTimeout = Duration(seconds: 100);

  static const Duration uiShortDelay = Duration(seconds: 1);

  static const Duration serverConnectionRetryDelay = Duration(seconds: 2);

  static const Duration serverConnectionExponentialBackoffBase =
      Duration(seconds: 1);

  static const Duration bluetoothSearchDelay = Duration(seconds: 1);

  static const Duration deviceFlowTimeout = Duration(seconds: 15);

  static const Duration readyArchiveTimeout = Duration(seconds: 10);

  static const Duration attemptDuration = Duration(seconds: 50);

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
