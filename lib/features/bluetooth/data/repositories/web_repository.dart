import 'package:bluetooth_per/features/web/data/source/device_info.dart';
import 'package:bluetooth_per/features/bluetooth/data/source/oper_list_response.dart';
import 'package:bluetooth_per/features/bluetooth/data/source/operation.dart';
import 'package:bluetooth_per/features/bluetooth/data/source/point.dart';
import 'package:bluetooth_per/features/bluetooth/utils/db_layer.dart';
import 'package:bluetooth_per/features/bluetooth/utils/web_layer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum OperStatus { ok, dbError, netError, filePathError }

class MainData {
  bool allSelected = false;

  DeviceInfo deviceInfo = DeviceInfo.empty();
  List<Operation> operations = [];

  String dbPath = '';
  //Database? db;

  // Кэш точек по dt операции, чтобы не дергать БД повторно
  final Map<int, List<Point>> _pointsCache = {};

  Future<OperStatus> awaitOperations() async {
    if (dbPath.isEmpty) return OperStatus.filePathError;
    if (dbPath.contains('/debug/')) return OperStatus.ok;

    Database db = await DbLayer.getDb(dbPath);
    db ??= await DbLayer.initDb(dbPath);
    if (db == null) return OperStatus.dbError;

    deviceInfo = await DbLayer.getDeviceInfo(db!);
    operations = await DbLayer.getOperationList(db!);
    setDtStopToOperations();
    return OperStatus.ok;
  }

  setDtStopToOperations() {
    if (operations.length > 1) {
      Operation prevOper = operations.first;
      for (int i = 1; i < operations.length; i++) {
        prevOper.dtStop = operations[i].dt - 1;
        prevOper = operations[i];
      }
    }
    operations.last.dtStop = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  Future<OperStatus> awaitOperationPoints(Operation op) async {
    if (dbPath.isEmpty) return OperStatus.filePathError;

    Database db = await DbLayer.getDb(dbPath);
    //db ??= await DbLayer.initDb(dbPath);
    if (db == null) return OperStatus.dbError;

    if (_pointsCache.containsKey(op.dt)) {
      op.points = _pointsCache[op.dt]!;
    } else {
      op.points = await DbLayer.getOperationPoints(db!, op.dt, op.dtStop);
      _pointsCache[op.dt] = op.points;
    }
    op.pCnt = op.points.length;
    print('operation points count  = ${op.pCnt}');
    //print(op.points.first.binValue);

    return OperStatus.ok;
  }

  Future<OperStatus> awaitOperationsCanSendStatus() async {
    if (operations.isEmpty) return OperStatus.ok;

    OperListResponse resp =
        await WebLayer.exportOperList(deviceInfo.serialNum, operations);
    if (resp.resultCode != 200) return OperStatus.netError;

    for (int dt in resp.operDtList) {
      int pos = operations.indexWhere((e) => e.dt == dt);
      if (pos >= 0) operations[pos].canSend = true;
    }

    return OperStatus.ok;
  }

  Future<int> awaitSendingOperation(Operation op) async {
    // Получить недостающие точки с сервера
    final missingPoints = await WebLayer.fetchMissingPoints(deviceInfo.serialNum, op.dt);
    if (missingPoints.isNotEmpty) {
      // Оставить только недостающие точки (по dt)
      op.points = op.points.where((p) => missingPoints.contains(p.dt)).toList();
      op.pCnt = op.points.length;
    }
    int resultCode = await WebLayer.exportOperData(deviceInfo.serialNum, op);
    return resultCode;
  }

  webCmdTest() {
    WebLayer.exportOperList(deviceInfo.serialNum, operations);
    WebLayer.exportOperData(deviceInfo.serialNum, operations.first);
  }

  resetOperationData() {
    deviceInfo = DeviceInfo.empty();
    operations.clear();
    allSelected = false;
  }

  globalChangeSelected() {
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
