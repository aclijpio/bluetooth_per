import 'dart:io';
import 'dart:typed_data';
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
