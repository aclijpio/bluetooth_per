import 'dart:io';

import 'package:http/http.dart' as http;

class ServerConnection {
  static const String _address = 'http://tms.quantor-t.ru:8080'; //Сервер
  //static const String _address = 'http://localhost:8080';

  static Future<dynamic> postReq(String message, String path) async {
    /// 401 - просрочен uuid
    /// 418 - неверный логин или пароль(8.1 request)
    /// 500 - ошибка на сервере
    /// 408 - время ожидания вышло в клиенте
    /// 524 - время ожидания вышло на сервере
    /// 15  - ошибка нашей обработки
    /// 400 - некорректный запрос
    /// 410 = long poll отменён
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

  /// То же, что [postReq], но делает до [maxAttempts] повторов
  /// с экспоненциальной задержкой (1s, 2s, 4s …).
  static Future<dynamic> postReqRetry(String message, String path,
      {int maxAttempts = 3}) async {
    int attempt = 0;
    while (attempt < maxAttempts) {
      final resp = await postReq(message, path);
      if (resp is! int || resp == 200) return resp;
      // ошибки 5xx / 408 / 524 пробуем ещё раз
      if (resp >= 500 || resp == 408 || resp == 524) {
        attempt++;
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: 1 << attempt)); // 1,2,4
          continue;
        }
      }
      return resp; // статус не требует повторов
    }
    return 500;
  }

  static Future<dynamic> getReq(String path) async {
    try {
      final res = await http.get(Uri.parse('$_address/$path'));
      if (res.statusCode == 200) {
        if (path == 'get_db_file') {
          // Return raw bytes for database file
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

  static Future<void> sendMessage(Socket socket, String message) async {
    print('Client: $message');
    socket.write(message);
    await Future.delayed(const Duration(seconds: 2));
  }
}
