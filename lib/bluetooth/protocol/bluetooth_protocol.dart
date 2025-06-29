import 'dart:convert';
import 'dart:typed_data';

/// Протокол обмена командами между Bluetooth клиентом и сервером
/// Обрабатывает запросы на обновление и получение архивов
class BluetoothProtocol {
  // Команды от клиента к серверу
  static const String CMD_UPDATE_ARCHIVE = "UPDATE_ARCHIVE";
  static const String CMD_GET_ARCHIVE = "GET_ARCHIVE";

  // Команды от сервера к клиенту
  static const String CMD_UPDATING_ARCHIVE = "UPDATING_ARCHIVE";
  static const String CMD_ARCHIVE_READY = "ARCHIVE_READY";
  static const String CMD_ERROR = "ERROR";
  static const String CMD_OK = "OK";

  BluetoothProtocol._(); // статический util-класс

  /// Команда «обнови архив»
  static Uint8List updateArchiveCmd() => _encode(CMD_UPDATE_ARCHIVE);

  /// Команда «получи архив по пути»
  static Uint8List getArchiveCmd(String archivePath) =>
      _encode('$CMD_GET_ARCHIVE:$archivePath');

  /// Проверяет, является ли команда корректной
  static bool isValidCommand(String command) {
    return command == CMD_UPDATE_ARCHIVE ||
        command.startsWith('$CMD_GET_ARCHIVE:') ||
        command == CMD_UPDATING_ARCHIVE ||
        command.startsWith('$CMD_ARCHIVE_READY:') ||
        command == CMD_ERROR ||
        command == CMD_OK;
  }

  /// Извлекает путь из команды GET_ARCHIVE
  static String? extractArchivePath(String command) {
    if (command.startsWith('$CMD_GET_ARCHIVE:')) {
      return command.substring(CMD_GET_ARCHIVE.length + 1);
    }
    return null;
  }

  /// Извлекает путь из команды ARCHIVE_READY
  static String? extractArchiveReadyPath(String command) {
    if (command.startsWith('$CMD_ARCHIVE_READY:')) {
      return command.substring(CMD_ARCHIVE_READY.length + 1);
    }
    return null;
  }

  /// Извлекает сообщение об ошибке из команды ERROR
  static String? extractErrorMessage(String command) {
    if (command.startsWith('$CMD_ERROR:')) {
      return command.substring(CMD_ERROR.length + 1);
    }
    return null;
  }

  // ============ helpers ============
  static Uint8List _encode(String msg) {
    final utf = utf8.encode(msg);
    final len = utf.length;
    final result = Uint8List(2 + len);
    result[0] = (len >> 8) & 0xFF;
    result[1] = len & 0xFF;
    result.setAll(2, utf);
    return result;
  }
}
