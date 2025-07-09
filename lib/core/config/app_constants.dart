/// Application-wide constants configuration
class AppConstants {
  AppConstants._();

  // App Information
  static const String appTitle = 'Quantor Data Transfer';
  static const String appLogoPath = 'assets/images/logo.svg';

  // Bluetooth & Web Service UUIDs
  static const String webUUID = "595a31f7-ad09-43ff-9a04-1c29bfe795cb";

  // File System
  static const String archivesDirName = '_Архив КВАНТОР';
  static const String notExportedSuffix = '_NEED_EXPORT';
  static const String dbExtension = '.db';

  // Device & Connection
  static const int maxRetryAttempts = 3;
  static const int maxFileDownloadRetries = 3;

  // Progress & Export
  static const double minProgressBarHeight = 6.0;
  static const double maxProgressBarHeight = 16.0;

  // Animation & UI
  static const int animationDelaySeconds = 1;
  static const double logoSize = 36.0;
  static const double iconSize = 28.0;

  // File naming helpers
  static String notExportedFileName(String deviceName, String fileName) {
    return '${deviceName}_${fileName}${notExportedSuffix}${dbExtension}';
  }

  static String exportedFileName(String deviceName, String fileName) {
    return '${deviceName}_${fileName}${dbExtension}';
  }
}