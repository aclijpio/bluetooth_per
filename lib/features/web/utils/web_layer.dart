import 'dart:convert';

import 'package:bluetooth_per/core/utils/constants.dart';
import 'package:bluetooth_per/features/web/data/source/oper_list_response.dart';
import 'package:dio/dio.dart';

import '../../../core/data/source/operation.dart';
import 'server_connection.dart';

class WebLayer {
  static const String constUuid = "595a31f7-ad09-43ff-9a04-1c29bfe795cb";

  static Future<OperListResponse> exportOperList(
      String serial, List<Operation> operations) async {
    Map<String, dynamic> request = {
      "serial": serial,
      "uuid": AppConstants.webApiUuid,
      "operations": operations.map((e) => e.dtAndCount()).toList(),
    };

    String reqStr = json.encode(request);
    print('[WebLayer] exportOperList: request=$reqStr');
    dynamic response =
        await ServerConnection.postReq(reqStr, 'get_archive_list')
            .timeout(AppConstants.webApiTimeout, onTimeout: () {
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
    print('[WebLayer] exportOperData: request=$reqStr');
    dynamic response =
        await ServerConnection.postReqRetry(reqStr, 'send_archive')
            .timeout(AppConstants.webApiLongTimeout, onTimeout: () {
      print('[WebLayer] exportOperData: timeout');
      return 408;
    });

    print('[WebLayer] exportOperData: response=$response');
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
    try {
      final response = await dio.post(
        '${AppConstants.webApiBaseUrl}/send_archive',
        data: reqStr,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 200) {
        return 200;
      } else {
        return response.statusCode ?? 500;
      }
    } catch (e) {
      return 500;
    }
  }
}
