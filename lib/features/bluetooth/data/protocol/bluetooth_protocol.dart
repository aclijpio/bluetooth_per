import 'dart:convert';
import 'dart:typed_data';

/// Инкапсулирует формат команд нашего SPP-протокола.
/// Сейчас поддерживаются две команды:
///   • LIST_FILES
///   • GET_FILE:<filename>
/// Каждая команда кодируется так же, как у Java-сервера:
///   2-байтовая длина (big-endian) + UTF-8-строка.
class BluetoothProtocol {
  BluetoothProtocol._(); // статический util-класс

  /// Команда «дай список файлов».
  static Uint8List listFilesCmd() => _encode('LIST_FILES');

  /// Команда «отдай файл [name]».
  static Uint8List getFileCmd(String name) => _encode('GET_FILE:$name');

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
