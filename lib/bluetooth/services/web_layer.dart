import 'dart:convert';

import 'package:bluetooth_per/bluetooth/services/server_connection.dart';

import '../entities/oper_list_response.dart';
import '../entities/operation.dart';

/// Слой для работы с веб-сервером
class WebLayer {
  static const String constUuid = "595a31f7-ad09-43ff-9a04-1c29bfe795cb";

  /// Экспорт списка операций
  static Future<OperListResponse> exportOperList(
      String serial, List<Operation> operations) async {
    Map<String, dynamic> request = {
      "serial": serial,
      "uuid": constUuid,
      "operations": operations.map((e) => e.dtAndCount()).toList(),
    };
    String reqStr = json.encode(request);
    // print(reqStr);
    // return OperListResponse(
    //     200, [1733207145, 1733207215, 1733212108, 1733387339, 1733739234]);
    dynamic response =
        await ServerConnection.postReqRetry(reqStr, 'get_archive_list')
            .timeout(const Duration(seconds: 15), onTimeout: () {
      return 408;
    });

    if (response.runtimeType == int) {
      return OperListResponse(response, []);
    } else {
      Map<String, dynamic> responseMap = json.decode(response);
      return OperListResponse(
        200,
        (responseMap['operations'] as List).map((e) => e as int).toList(),
      );
    }
  }

  /// Экспорт данных операции
  static Future<int> exportOperData(String serial, Operation op) async {
    Map<String, dynamic> request = {
      "serial": serial,
      "uuid": constUuid,
      "operation": op.toSendMap(),
      "points": op.points.map((e) => e.toSendMap()).toList(),
    };
    String reqStr = json.encode(request);
    //print(reqStr);
    // await Future.delayed(Duration(seconds: 2)); //!debug
    // return 200;
    dynamic response =
        await ServerConnection.postReqRetry(reqStr, 'send_archive')
            .timeout(const Duration(seconds: 100040), onTimeout: () {
      return 408;
    });

    if (response.runtimeType == int) {
      return response;
    } else {
      return 200;
    }
  }

  /// Получение недостающих точек
  static Future<List<int>> fetchMissingPoints(String serial, int operDt) async {
    final request = json.encode({
      "serial": serial,
      "uuid": constUuid,
      "operDt": operDt,
    });
    final response =
        await ServerConnection.postReqRetry(request, 'get_missing_points');
    if (response.runtimeType == int) return [];
    final responseMap = json.decode(response);
    // Ожидается, что сервер вернёт список индексов или dt точек
    return (responseMap['missingPoints'] as List).map((e) => e as int).toList();
  }
}
