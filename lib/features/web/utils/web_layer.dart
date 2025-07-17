import 'dart:convert';

import 'package:bluetooth_per/core/config.dart';
import 'package:bluetooth_per/core/utils/log_manager.dart';
import 'package:bluetooth_per/features/web/data/source/oper_list_response.dart';
import 'package:dio/dio.dart';

import '../../../core/data/source/operation.dart';
import 'server_connection.dart';

class WebLayer {
  static const String constUuid = AppConfig.webUUID;

  static Future<OperListResponse> exportOperList(
      String serial, List<Operation> operations) async {
    await LogManager.web(
        'WEB', 'Начинаем экспорт списка операций для устройства: $serial');

    // Подсчитываем общее количество точек
    final totalPoints =
        operations.fold<int>(0, (sum, op) => sum + op.points.length);
    final operationsWithPoints =
        operations.where((op) => op.points.isNotEmpty).toList();

    await LogManager.web('WEB',
        'Всего операций: ${operations.length}, операций с точками: ${operationsWithPoints.length}, общее количество точек: $totalPoints');

    Map<String, dynamic> request = {
      "serial": serial,
      "uuid": constUuid,
      "operations": operationsWithPoints.map((e) => e.dtAndCount()).toList(),
    };

    String reqStr = json.encode(request);
    await LogManager.web(
        'WEB', 'Отправляем запрос с ${operationsWithPoints.length} операциями');
    print('[WebLayer] exportOperList: request=$reqStr');
    dynamic response =
        await ServerConnection.postReq(reqStr, 'get_archive_list')
            .timeout(AppConfig.webRequestTimeout, onTimeout: () {
      return 408;
    });

    print('[WebLayer] exportOperList: response=$response');

    if (response.runtimeType == int) {
      await LogManager.web(
          'WEB', 'Запрос завершился с ошибкой: $response', LogLevel.error);
      return OperListResponse(response, []);
    } else {
      Map<String, dynamic> responseMap = json.decode(response);
      final operationsList =
          (responseMap['operations'] as List).map((e) => e as int).toList();
      await LogManager.web(
          'WEB', 'Запрос успешен, получено ${operationsList.length} операций');
      return OperListResponse(200, operationsList);
    }
  }

  static Future<int> exportOperData(String serial, Operation op) async {
    await LogManager.web('WEB',
        'Начинаем экспорт данных операции для устройства: $serial, операция: ${op.dt}');

    await LogManager.web('WEB',
        'Операция dt=${op.dt}: количество точек=${op.points.length}, pCnt=${op.pCnt}');

    Map<String, dynamic> request = {
      "serial": serial,
      "uuid": constUuid,
      "operation": op.toSendMap(),
      "points": op.points.map((e) => e.toSendMap()).toList(),
    };
    String reqStr = json.encode(request);
    await LogManager.web(
        'WEB', 'Отправляем операцию с ${op.points.length} точками данных');
    dynamic response =
        await ServerConnection.postReqRetry(reqStr, 'send_archive')
            .timeout(AppConfig.longRequestTimeout, onTimeout: () {
      return 408;
    });

    if (response.runtimeType == int) {
      await LogManager.web('WEB',
          'Экспорт операции завершился с ошибкой: $response', LogLevel.error);
      return response;
    } else {
      await LogManager.web('WEB', 'Экспорт операции завершился успешно');
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
      LogManager.error('WEB',
          'Ошибка экспорта операции с прогрессом для устройства $serial, операция ${op.dt}: $e');
      onProgress(1.0);
      return 500;
    }
  }
}
