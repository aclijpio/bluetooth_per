class AppConfig {
  /// Имя папки для хранения архивов
  static const String archivesDirName = '_Архив КВАНТОР';
  static const String webUUID = "595a31f7-ad09-43ff-9a04-1c29bfe795cb";

  static const String notExportedSuffix = '_NEED_EXPORT';
  static const String dbExtension = '.db';

  static String notExportedFileName(String deviceName, String fileName) {
    return '${deviceName}_${fileName}${notExportedSuffix}${dbExtension}';
  }

  static String exportedFileName(String deviceName, String fileName) {
    return '${deviceName}_${fileName}${dbExtension}';
  }
}
