import 'package:bluetooth_per/core/data/source/device_info.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import 'package:bluetooth_per/core/data/source/point.dart';
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

  final Map<int, List<Point>> _pointsCache = {};

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

    Database db = await DbLayer.getDb(dbPath);
    db ??= await DbLayer.initDb(dbPath);
    if (db == null) {
      print('[MainData] awaitOperations: dbError');
      return OperStatus.dbError;
    }

    try {
      final res =
          await db.query('tmc_agregat', columns: ['serNumber', 'stNumber']);
      if (res.isNotEmpty) {
      } else {}
    } catch (e) {
      print('[MainData] ERROR querying tmc_agregat: $e');
    }

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

    // Если запрос не удался (нет сети, 5xx и т.п.) – сбрасываем флаги canSend,
    // чтобы таблица не показывала «устаревшие» данные прошлой сессии.
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
    print('[MainData] awaitOperationsCanSendStatus: canSend updated');
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
