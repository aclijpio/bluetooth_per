import 'package:bluetooth_per/core/data/source/device_info.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import 'package:bluetooth_per/core/data/source/point.dart';
import 'package:bluetooth_per/features/web/data/source/oper_list_response.dart';
import 'package:bluetooth_per/features/web/utils/db_layer.dart';
import 'package:bluetooth_per/features/web/utils/web_layer.dart';
import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../di/injection_container.dart' as di;

enum OperStatus { ok, dbError, netError, filePathError }

class MainData {
  late final Logger _logger;
  
  bool allSelected = false;

  DeviceInfo deviceInfo = DeviceInfo.empty();
  List<Operation> operations = [];

  String dbPath = '';
  //Database? db;

  final Map<int, List<Point>> _pointsCache = {};

  MainData() {
    _logger = di.sl<Logger>();
  }

  Future<OperStatus> awaitOperations() async {
    _logger.d('awaitOperations: dbPath=$dbPath');
    if (dbPath.isEmpty) {
      _logger.w('awaitOperations: filePathError - dbPath is empty');
      return OperStatus.filePathError;
    }
    if (dbPath.contains('/debug/')) {
      _logger.i('awaitOperations: debug path detected, skipping database operations');
      return OperStatus.ok;
    }

    try {
      Database db = await DbLayer.getDb(dbPath);
      db ??= await DbLayer.initDb(dbPath);
      if (db == null) {
        _logger.e('awaitOperations: failed to initialize database');
        return OperStatus.dbError;
      }

      try {
        final res = await db.query('tmc_agregat', columns: ['serNumber', 'stNumber']);
        _logger.d('tmc_agregat query result: ${res.length} rows');
      } catch (e) {
        _logger.e('Error querying tmc_agregat: $e');
      }

      deviceInfo = await DbLayer.getDeviceInfo(db);
      operations = await DbLayer.getOperationList(db);

      setDtStopToOperations();
      _logger.i('Successfully loaded ${operations.length} operations for device ${deviceInfo.serialNum}');
      return OperStatus.ok;
    } catch (e) {
      _logger.e('Unexpected error in awaitOperations: $e');
      return OperStatus.dbError;
    }
  }

  void setDtStopToOperations() {
    if (operations.length > 1) {
      Operation prevOper = operations.first;
      for (int i = 1; i < operations.length; i++) {
        prevOper.dtStop = operations[i].dt - 1;
        prevOper = operations[i];
      }
    }
    if (operations.isNotEmpty) {
      operations.last.dtStop = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
  }

  Future<OperStatus> awaitOperationPoints(Operation op) async {
    if (dbPath.isEmpty) {
      _logger.w('awaitOperationPoints: dbPath is empty');
      return OperStatus.filePathError;
    }

    try {
      Database db = await DbLayer.getDb(dbPath);
      if (db == null) {
        _logger.e('awaitOperationPoints: database is null');
        return OperStatus.dbError;
      }

      if (_pointsCache.containsKey(op.dt)) {
        op.points = _pointsCache[op.dt]!;
        _logger.d('Retrieved ${op.points.length} points from cache for operation ${op.dt}');
      } else {
        op.points = await DbLayer.getOperationPoints(db, op.dt, op.dtStop);
        _pointsCache[op.dt] = op.points;
        _logger.d('Loaded ${op.points.length} points for operation ${op.dt}');
      }

      op.pCnt = op.points.length;
      return OperStatus.ok;
    } catch (e) {
      _logger.e('Error in awaitOperationPoints: $e');
      return OperStatus.dbError;
    }
  }

  Future<OperStatus> awaitOperationsCanSendStatus() async {
    if (operations.isEmpty) {
      _logger.d('No operations to check for send status');
      return OperStatus.ok;
    }

    try {
      OperListResponse resp = await WebLayer.exportOperList(deviceInfo.serialNum, operations);

      // Если запрос не удался (нет сети, 5xx и т.п.) – сбрасываем флаги canSend,
      // чтобы таблица не показывала «устаревшие» данные прошлой сессии.
      if (resp.resultCode != 200) {
        _logger.w('Server request failed with code ${resp.resultCode}, marking all operations as unavailable');
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
        if (pos >= 0) {
          operations[pos].canSend = true;
        }
      }
      
      final canSendCount = operations.where((op) => op.canSend).length;
      _logger.i('Updated canSend status: $canSendCount operations can be sent');
      return OperStatus.ok;
    } catch (e) {
      _logger.e('Error in awaitOperationsCanSendStatus: $e');
      return OperStatus.netError;
    }
  }

  Future<int> awaitSendingOperation(Operation op) async {
    try {
      _logger.d('Sending operation ${op.dt} for device ${deviceInfo.serialNum}');
      int resultCode = await WebLayer.exportOperData(deviceInfo.serialNum, op);
      _logger.i('Operation ${op.dt} sent with result code: $resultCode');
      return resultCode;
    } catch (e) {
      _logger.e('Error sending operation ${op.dt}: $e');
      return 500; // Internal server error
    }
  }

  Future<int> awaitSendingOperationWithProgress(
      Operation op, void Function(double) onProgress) async {
    try {
      _logger.d('Sending operation ${op.dt} with progress tracking');
      int resultCode = await WebLayer.exportOperDataWithProgress(
          deviceInfo.serialNum, op, onProgress);
      _logger.i('Operation ${op.dt} sent with progress tracking, result code: $resultCode');
      return resultCode;
    } catch (e) {
      _logger.e('Error sending operation ${op.dt} with progress: $e');
      return 500;
    }
  }

  void webCmdTest() {
    _logger.d('Testing web commands');
    WebLayer.exportOperList(deviceInfo.serialNum, operations);
    if (operations.isNotEmpty) {
      WebLayer.exportOperData(deviceInfo.serialNum, operations.first);
    }
  }

  void resetOperationData() {
    _logger.i('Resetting operation data');
    deviceInfo = DeviceInfo.empty();
    operations.clear();
    _pointsCache.clear();
    allSelected = false;
  }

  void globalChangeSelected() {
    _logger.d('Global change selected: allSelected=$allSelected');
    final canSendOperations = operations.where((e) => e.canSend);
    for (final element in canSendOperations) {
      element.selected = allSelected;
    }
  }

  void allSelectedFlagSynchronize() {
    final canSendOperations = operations.where((e) => e.canSend).toList();
    if (canSendOperations.isEmpty) {
      allSelected = false;
      return;
    }
    allSelected = canSendOperations.every((op) => op.selected);
  }
}
