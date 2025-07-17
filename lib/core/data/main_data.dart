import 'dart:convert';

import 'package:bluetooth_per/core/data/source/device_info.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import 'package:bluetooth_per/core/data/source/point.dart';
import 'package:bluetooth_per/core/utils/log_manager.dart';
import 'package:bluetooth_per/features/web/data/source/oper_list_response.dart';
import 'package:bluetooth_per/features/web/utils/db_layer.dart';
import 'package:bluetooth_per/features/web/utils/web_layer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum OperStatus { ok, dbError, netError, filePathError }

class MainData {
  bool allSelected = false;

  DeviceInfo deviceInfo = DeviceInfo.empty();
  List<Operation> operations = [];

  String dbPath = '';
  //Database? db;

  void dispose() {
    operations.clear();
    deviceInfo = DeviceInfo.empty();
    dbPath = '';
    allSelected = false;
    print('[MainData] MainData disposed');
  }

  Future<OperStatus> awaitOperations() async {
    print('[MainData] awaitOperations: dbPath=$dbPath');
    if (dbPath.isEmpty) {
      print('[MainData] awaitOperations: filePathError');
      return OperStatus.filePathError;
    }
    if (dbPath.contains('/debug/')) {
      print('[MainData] awaitOperations: debug path, skipping');
      return OperStatus.ok;
    }

    await DbLayer.resetConnection();

    Database db = await DbLayer.getDb(dbPath);
    db ??= await DbLayer.initDb(dbPath);
    if (db == null) {
      LogManager.error(
          'DB', 'Не удалось инициализировать базу данных: $dbPath');
      return OperStatus.dbError;
    }

    try {
      final res = await db.query('tmc_config',
          columns: ['config'], where: 'record_type = 1');
      if (res.isNotEmpty) {
      } else {}
    } catch (e) {
      LogManager.error('DB', 'Ошибка при запросе конфигурации из БД: $e');
      return OperStatus.dbError;
    }

    deviceInfo = await DbLayer.getDeviceInfo(db!);
    operations = await DbLayer.getOperationList(db!);

    await setDtStopToOperations();
    return OperStatus.ok;
  }

  Future<void> setDtStopToOperations() async {
    await LogManager.database(
        'DB', 'Устанавливаем dtStop для ${operations.length} операций');

    if (operations.length > 1) {
      Operation prevOper = operations.first;
      for (int i = 1; i < operations.length; i++) {
        final oldDtStop = prevOper.dtStop;
        prevOper.dtStop = operations[i].dt - 1;
        await LogManager.database('DB',
            'Операция dt=${prevOper.dt}: dtStop изменен с $oldDtStop на ${prevOper.dtStop}');
        prevOper = operations[i];
      }
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final oldDtStop = operations.last.dtStop;
    operations.last.dtStop = currentTime;
    await LogManager.database('DB',
        'Последняя операция dt=${operations.last.dt}: dtStop изменен с $oldDtStop на $currentTime');
  }

  Future<OperStatus> awaitOperationPoints(Operation op) async {
    if (dbPath.isEmpty) {
      return OperStatus.filePathError;
    }

    Database db = await DbLayer.getDb(dbPath);
    if (db == null) {
      LogManager.error(
          'DB', 'Не удалось получить БД для операции ${op.dt}: $dbPath');
      return OperStatus.dbError;
    }

    await LogManager.database(
        'DB', 'Загружаем точки для операции dt=${op.dt}, dtStop=${op.dtStop}');

    op.points = await DbLayer.getOperationPoints(db!, op.dt, op.dtStop);
    op.pCnt = op.points.length;

    await LogManager.database(
        'DB', 'Операция dt=${op.dt}: загружено ${op.pCnt} точек');

    return OperStatus.ok;
  }

  Future<OperStatus> awaitOperationsCanSendStatus() async {
    if (operations.isEmpty) {
      return OperStatus.ok;
    }

    OperListResponse resp =
        await WebLayer.exportOperList(deviceInfo.serialNum, operations);

    if (resp.resultCode != 200) {
      for (final op in operations) {
        op.canSend = false;
        op.checkError = true;
        op.unavailable = true;
      }

      return OperStatus.netError;
    }

    for (final op in operations) {
      op.checkError = false;
      op.unavailable = false;
    }
    for (int dt in resp.operDtList) {
      int pos = operations.indexWhere((e) => e.dt == dt);
      if (pos >= 0) operations[pos].canSend = true;
    }
    return OperStatus.ok;
  }

  Future<int> awaitSendingOperation(Operation op) async {
    int resultCode = await WebLayer.exportOperData(deviceInfo.serialNum, op);
    return resultCode;
  }

  Future<int> awaitSendingOperationWithProgress(
      Operation op, void Function(double) onProgress) async {
    int resultCode = await WebLayer.exportOperDataWithProgress(
        deviceInfo.serialNum, op, (progress) {});
    return resultCode;
  }

  webCmdTest() {
    WebLayer.exportOperList(deviceInfo.serialNum, operations);
    WebLayer.exportOperData(deviceInfo.serialNum, operations.first);
  }

  resetOperationData() {
    print('[MainData] resetOperationData');
    deviceInfo = DeviceInfo.empty();
    operations.clear();
    allSelected = false;
  }

  void setDbPath(String newPath) {
    if (dbPath != newPath) {
      dbPath = newPath;
      print('[MainData] DB path changed');
    }
  }

  globalChangeSelected() {
    print('[MainData] globalChangeSelected: allSelected=$allSelected');
    operations
        .where((e) => e.canSend)
        .forEach((element) => element.selected = allSelected);
  }

  allSelectedFlagSynchronize() {
    if (operations.where((e) => e.canSend).toList().isEmpty) {
      allSelected = false;

      return;
    }
    allSelected =
        operations.where((e) => e.canSend && !e.selected).toList().isEmpty;
  }
}
