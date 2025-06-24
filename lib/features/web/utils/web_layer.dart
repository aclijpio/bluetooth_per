import 'dart:convert';

import 'package:bluetooth_per/features/web/data/source/oper_list_response.dart';
import 'package:bluetooth_per/features/web/data/source/operation.dart';

import 'server_connection.dart';

class WebLayer {
  static const String constUuid = "595a31f7-ad09-43ff-9a04-1c29bfe795cb";

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
}
