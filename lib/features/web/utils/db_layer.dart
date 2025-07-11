import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bluetooth_per/core/data/source/device_info.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import 'package:bluetooth_per/core/data/source/point.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as desktop;

class DbLayer {
  static Database? _db;
  static String curDbPath = '';

  static Future<Database> getDb(String newPath) async {
    if ((newPath != curDbPath) && (_db != null)) {
      await _db?.close();
      _db = null;
    }

    if (_db != null) {
      return _db!;
    }

    try {
      _db = await initDb(newPath);
      curDbPath = newPath;
      return _db!;
    } catch (e) {
      throw Exception('Failed to initialize database: $e');
    }
  }

  /// Инициализирует базу данных в зависимости от платформы
  static Future<Database> initDb(String dbPath) async {
    if (_isDesktop()) {
      desktop.sqfliteFfiInit();
      desktop.databaseFactory = desktop.databaseFactoryFfi;
      return await desktop.databaseFactory.openDatabase(dbPath,
          options: desktop.OpenDatabaseOptions(readOnly: true));
    } else {
      // Инициализация для Android/iOS/Web
      return await mobile.openDatabase(dbPath, readOnly: true);
    }
  }

  static bool _isDesktop() {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static Future<DeviceInfo> getDeviceInfo(Database db) async {
    try {
/*      final res =
          await db.query('tmc_agregat', columns: ['serNumber', 'stNumber']);
      return res.isEmpty
          ? DeviceInfo(serialNum: 'N\\A', gosNum: 'N\\A')
          : DeviceInfo.fromMap(res.first);*/

      final res = await db.query('tmc_config',
          columns: ['config'], where: 'record_type = 1');

      if (res.isEmpty) {
        throw Exception('Configuration not found in database');
      }

      final configJson = res.first['config'] as String;
      final Map<String, dynamic> config = json.decode(configJson);

      final ktaSerial = config['kta_Serial']?.toString() ?? 'N/A';
      final stateNumber = config['state_Number']?.toString() ?? 'N/A';

      return DeviceInfo(serialNum: ktaSerial, gosNum: stateNumber);
    } catch (e) {
      throw Exception('Failed to get device info: $e');
    }
  }

  static Future<List<Operation>> getOperationList(Database db) async {
    var res = await db.query('tmc_operations', columns: [
      'DT',
      'max_pressure',
      'Organization',
      'work_type',
      'NGDU',
      'Field',
      'Department',
      'Cluster',
      'Hole',
      'brigade',
      'lat',
      'lon',
      'equipment'
    ]);
    if (res.isEmpty) {
      return [];
    } else {
      return res.map((e) => Operation.fromMap(e)).toList();
    }
  }

  static Future<List<Point>> getOperationPoints(
      Database db, int dt1, int dt2) async {
    var res = await db.query(
      'tmc_points',
      columns: ['date', 'point', 'lat', 'lon', 'speed'],
      where: 'date > ? and date < ?',
      whereArgs: [dt1, dt2],
    );
    if (res.isEmpty) {
      return [];
    } else {
      List<Point> resultList = [];
      Set<int> seenDt = {};
      for (var e in res) {
        Point point = Point.fromMap(e);
        if (seenDt.add(point.dt)) {
          resultList.add(point);
        }
      }
      return resultList;
      //return res.map((e) => Point.fromMap(e)).toList();
    }
  }

  static Future<int> getOperationPointsLength(
      Database db, int dt1, int dt2) async {
    var res = await db.query(
      'tmc_points',
      columns: ['date', 'point', 'lat', 'lon', 'speed'],
      where: 'date > ? and date < ?',
      whereArgs: [dt1, dt2],
    );
    return res.length;
  }

  static Future<void> closeDb() async {
    await _db?.close();
    _db = null;
    curDbPath = '';
  }
}
