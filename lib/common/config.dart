import '../core/config/app_constants.dart';

/// Legacy config class - use AppConstants instead
/// @deprecated Use AppConstants from core/config/app_constants.dart
class AppConfig {
  /// Имя папки для хранения архивов
  static const String archivesDirName = AppConstants.archivesDirName;
  static const String webUUID = AppConstants.webUUID;

  static const String notExportedSuffix = AppConstants.notExportedSuffix;
  static const String dbExtension = AppConstants.dbExtension;

  static String notExportedFileName(String deviceName, String fileName) {
    return AppConstants.notExportedFileName(deviceName, fileName);
  }

  static String exportedFileName(String deviceName, String fileName) {
    return AppConstants.exportedFileName(deviceName, fileName);
  }
}
