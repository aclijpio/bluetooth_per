import 'dart:convert';

import 'package:bluetooth_per/common/config.dart';
import 'package:bluetooth_per/features/web/data/source/oper_list_response.dart';
import 'package:dio/dio.dart';

import '../../../core/data/source/operation.dart';
import 'server_connection.dart';

class WebLayer {
  static const String constUuid = AppConfig.webUUID;

  static Future<OperListResponse> exportOperList( String serial, List<Operation> operations) async {
    Map<String, dynamic> request = {
      "serial": serial,
      "uuid": constUuid,
      "operations": operations.map((e) => e.dtAndCount()).toList(),
    };

    String reqStr = json.encode(request);
    print('[WebLayer] exportOperList: request=$reqStr');
    dynamic response =
        await ServerConnection.postReq(reqStr, 'get_archive_list')
            .timeout(const Duration(seconds: 15), onTimeout: () {
      return 408;
    });

    print('[WebLayer] exportOperList: response=$response');
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

  static Future<int> exportOperData(String serial, Operation op) async {
    Map<String, dynamic> request = {
      "serial": serial,
      "uuid": constUuid,
      "operation": op.toSendMap(),
      "points": op.points.map((e) => e.toSendMap()).toList(),
    };
    String reqStr = json.encode(request);
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
  static Future<int> exportOperDataWithProgress(
      String serial, Operation op, void Function(double) onProgress) async {
    Map<String, dynamic> request = {
      "serial": serial,
      "uuid": constUuid,
      "operation": op.toSendMap(),
      "points": op.points.map((e) => e.toSendMap()).toList(),
    };
    String reqStr = json.encode(request);
    final dio = Dio();
    print("Request " + reqStr);
    try {
      final response = await dio.post(
        'http://tms.quantor-t.ru:8080/send_archive',
        data: reqStr,
        options: Options(headers: {'Content-Type': 'application/json'}),
        onSendProgress: (int sent, int total) {
          if (total > 0) {
            onProgress(sent / total);
          }
        },
      );
      if (response.statusCode == 200) {
        onProgress(1.0);
        return 200;
      } else {
        onProgress(1.0);
        return response.statusCode ?? 500;
      }
    } catch (e) {
      onProgress(1.0);
      return 500;
    }
  }
}
