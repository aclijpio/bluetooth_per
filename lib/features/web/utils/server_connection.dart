import 'dart:io';

import 'package:bluetooth_per/core/utils/constants.dart';
import 'package:http/http.dart' as http;

class ServerConnection {
  static const String _address = AppConstants.webApiBaseUrl; //Сервер
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
    print('[ServerConnection] postReq: path=$path message=$message');
    try {
      final res = await http.post(Uri.parse('$_address/$path'), body: message);
      print('[ServerConnection] postReq: statusCode=${res.statusCode}');
      if (res.statusCode == 200) {
        print('[ServerConnection] postReq: response=${res.body}');
        return res.body.toString();
      } else {
        print('[ServerConnection] postReq: error statusCode=${res.statusCode}');
        return res.statusCode;
      }
    } catch (e) {
      print('[ServerConnection] postReq: exception=$e');
      return 500;
    }
  }

  /// То же, что [postReq], но делает до [maxAttempts] повторов
  /// с экспоненциальной задержкой (1s, 2s, 4s …).
  static Future<dynamic> postReqRetry(String message, String path,
      {int maxAttempts = AppConstants.bluetoothScanMaxAttempts}) async {
    int attempt = 0;
    while (attempt < maxAttempts) {
      print(
          '[ServerConnection] postReqRetry: attempt=${attempt + 1}/$maxAttempts');
      final resp = await postReq(message, path);
      if (resp is! int || resp == 200) {
        print('[ServerConnection] postReqRetry: success');
        return resp;
      }
      // ошибки 5xx / 408 / 524 пробуем ещё раз
      if (resp >= 500 || resp == 408 || resp == 524) {
        attempt++;
        print('[ServerConnection] postReqRetry: retrying after error $resp');
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: 1 << attempt)); // 1,2,4
          continue;
        }
      }
      print(
          '[ServerConnection] postReqRetry: non-retryable or max attempts, resp=$resp');
      return resp; // статус не требует повторов
    }
    print(
        '[ServerConnection] postReqRetry: failed after $maxAttempts attempts');
    return 500;
  }

  static Future<dynamic> getReq(String path) async {
    print('[ServerConnection] getReq: path=$path');
    try {
      final res = await http.get(Uri.parse('$_address/$path'));
      print('[ServerConnection] getReq: statusCode=${res.statusCode}');
      if (res.statusCode == 200) {
        if (path == 'get_db_file') {
          print('[ServerConnection] getReq: returning bodyBytes');
          // Return raw bytes for database file
          return res.bodyBytes;
        }
        print('[ServerConnection] getReq: response=${res.body}');
        return res.body.toString();
      } else {
        print('[ServerConnection] getReq: error statusCode=${res.statusCode}');
        return res.statusCode;
      }
    } catch (e) {
      print('[ServerConnection] getReq: exception=$e');
      return 500;
    }
  }

  static Future<void> sendMessage(Socket socket, String message) async {
    print('[ServerConnection] sendMessage: $message');
    socket.write(message);
    await Future.delayed(const Duration(seconds: 2));
  }
}
