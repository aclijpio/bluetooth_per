import 'dart:io';

import 'package:bluetooth_per/common/config.dart';
import 'package:http/http.dart' as http;

class ServerConnection {
  /// Адрес сервера
  static const String _address = AppConfig.serverBaseUrl;

  /// Отправляет POST-запрос на сервер.
  ///
  /// Возвращает тело ответа в виде [String] при успехе (код 200),
  /// в противном случае возвращает код статуса [int].
  ///
  /// Коды ошибок:
  /// - 401: Просрочен UUID
  /// - 418: Неверный логин или пароль
  /// - 500: Ошибка на сервере
  /// - 408: Таймаут на стороне клиента
  /// - 524: Таймаут на стороне сервера
  /// - 400: Некорректный запрос
  /// - 410: Long poll отменен
  static Future<dynamic> postReq(String message, String path) async {
    try {
      final res = await http.post(Uri.parse('$_address/$path'), body: message);
      if (res.statusCode == 200) {
        return res.body.toString();
      } else {
        return res.statusCode;
      }
    } catch (e) {
      return 500;
    }
  }

  /// Отправляет POST-запрос с несколькими попытками.
  ///
  /// Выполняет до [maxAttempts] попыток с экспоненциальной задержкой
  /// (например, 1с, 2с, 4с...).
  static Future<dynamic> postReqRetry(String message, String path,
      {int maxAttempts = 3}) async {
    int attempt = 0;
    while (attempt < maxAttempts) {
      final resp = await postReq(message, path);
      if (resp is! int || resp == 200) {
        return resp;
      }
      // Повторяем при ошибках 5xx, 408, 524
      if (resp >= 500 || resp == 408 || resp == 524) {
        attempt++;
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(
              seconds:
                  AppConfig.serverConnectionExponentialBackoffBase.inSeconds <<
                      attempt));
          continue;
        }
      }
      // Неповторяемые ошибки или достигнут лимит попыток
      return resp;
    }
    return 500;
  }

  /// Отправляет GET-запрос на сервер.
  ///
  /// Для пути 'get_db_file' возвращает тело ответа как [Uint8List],
  /// в остальных случаях - как [String].
  static Future<dynamic> getReq(String path) async {
    try {
      final res = await http.get(Uri.parse('$_address/$path'));
      if (res.statusCode == 200) {
        if (path == 'get_db_file') {
          // Для файла БД возвращаем байты
          return res.bodyBytes;
        }
        return res.body.toString();
      } else {
        return res.statusCode;
      }
    } catch (e) {
      return 500;
    }
  }

  /// Отправляет сообщение через сокет.
  static Future<void> sendMessage(Socket socket, String message) async {
    socket.write(message);
    await Future.delayed(AppConfig.serverConnectionRetryDelay);
  }
}
