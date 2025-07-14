import 'dart:convert';

import 'package:bluetooth_per/core/data/source/device_info.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import 'package:bluetooth_per/core/data/source/point.dart';
import 'package:bluetooth_per/core/utils/memory_monitor.dart';
import 'package:bluetooth_per/features/web/data/source/oper_list_response.dart';
import 'package:bluetooth_per/features/web/utils/db_layer.dart';
import 'package:bluetooth_per/features/web/utils/web_layer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum OperStatus { ok, dbError, netError, filePathError }

class MainData {
  bool allSelected = false;
  static const int _maxCacheSize = 50;

  DeviceInfo deviceInfo = DeviceInfo.empty();
  List<Operation> operations = [];

  String dbPath = '';
  //Database? db;

  final Map<int, List<Point>> _pointsCache = {};

  void _cleanupOldCacheEntries() {
    if (_pointsCache.length > _maxCacheSize) {
      final entries = _pointsCache.entries.toList();
      entries.sort((a, b) => a.key.compareTo(b.key));

      final toRemove = entries.take(_pointsCache.length - _maxCacheSize);
      for (final entry in toRemove) {
        _pointsCache.remove(entry.key);
      }
      MemoryMonitor.logCacheSize('PointsCache', _pointsCache.length);
      print(
          '[MainData] Cleaned cache: removed ${toRemove.length} entries, ${_pointsCache.length} remaining');
    }
  }

  void clearCache() {
    final oldSize = _pointsCache.length;
    _pointsCache.clear();
    MemoryMonitor.logCacheSize('PointsCache', 0);
    print('[MainData] Cache cleared completely (was $oldSize entries)');
  }

  void dispose() {
    MemoryMonitor.logMemoryUsage('MainData.dispose');
    clearCache();
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

    Database db = await DbLayer.getDb(dbPath);
    db ??= await DbLayer.initDb(dbPath);
    if (db == null) {
      print('[MainData] awaitOperations: dbError');
      return OperStatus.dbError;
    }

    try {
      final res = await db.query('tmc_config',
          columns: ['config'], where: 'record_type = 1');
      if (res.isNotEmpty) {
      } else {}
    } catch (e) {
      return OperStatus.dbError;
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
    if (dbPath.isEmpty) {
      return OperStatus.filePathError;
    }

    Database db = await DbLayer.getDb(dbPath);
    if (db == null) {
      return OperStatus.dbError;
    }

    if (_pointsCache.containsKey(op.dt)) {
      op.points = _pointsCache[op.dt]!;
    } else {
      op.points = await DbLayer.getOperationPoints(db!, op.dt, op.dtStop);
      _pointsCache[op.dt] = op.points;
      _cleanupOldCacheEntries();
    }

    op.pCnt = op.points.length;
    print('operation points count  = ${op.pCnt}');

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
    clearCache();
  }

  void setDbPath(String newPath) {
    if (dbPath != newPath) {
      clearCache();
      dbPath = newPath;
      print('[MainData] DB path changed, cache cleared');
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
