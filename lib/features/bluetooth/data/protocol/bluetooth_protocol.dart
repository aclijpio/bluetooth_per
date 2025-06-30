import 'dart:convert';
import 'dart:typed_data';

/// Инкапсулирует формат команд нашего SPP-протокола.
/// Сейчас поддерживаются две команды:
///   • LIST_FILES
///   • GET_FILE:<filename>
/// Каждая команда кодируется так же, как у ява-сервера:
///   2-байтовая длина (big-endian) + UTF-8-строка.
class BluetoothProtocol {
  BluetoothProtocol._();

  /// Команда «дай список файлов».
  static Uint8List listFilesCmd() => _encode('LIST_FILES');

  /// Команда «запросить получение архива по [path]».
  static Uint8List getArchiveCmd(String path) => _encode('GET_ARCHIVE:$path');

  /// Команда «запросить обновление архива».
  static Uint8List updateArchiveCmd() => _encode('UPDATE_ARCHIVE');

  /// Проверка, что это ответ ARCHIVE_UPDATING
  static bool isArchiveUpdating(Uint8List data) {
    final msg = _decode(data);
    return msg == 'UPDATING_ARCHIVE' || msg == 'ARCHIVE_UPDATING';
  }

  /// Проверка, что это ответ ARCHIVE_READY
  static bool isArchiveReady(Uint8List data) {
    final msg = _decode(data);
    return msg.startsWith('ARCHIVE_READY');
  }

  /// Если сообщение ARCHIVE_READY содержит путь, извлекаем его.
  static String? extractArchivePath(Uint8List data) {
    final msg = _decode(data);
    const prefix = 'ARCHIVE_READY:';
    if (msg.startsWith(prefix)) {
      return msg.substring(prefix.length);
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

  static String _decode(Uint8List data) {
    if (data.length < 2) return '';
    final len = (data[0] << 8) | data[1];
    if (data.length < 2 + len) return '';
    return utf8.decode(data.sublist(2, 2 + len));
  }
}
