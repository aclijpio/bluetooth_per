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
      final res =
          await db.query('tmc_agregat', columns: ['serNumber', 'stNumber']);
      return res.isEmpty
          ? DeviceInfo(serialNum: '', gosNum: '')
          : DeviceInfo.fromMap(res.first);
    } catch (e) {
      throw Exception('Failed to get device info: $e');
    }
  }

  static Future<List<Operation>> getOperationList(Database db) async {
    try {
      final res = await db.query('tmc_operations', columns: [
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
      return res.map((e) => Operation.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Failed to get operation list: $e');
    }
  }

  static Future<List<Point>> getOperationPoints(
      Database db, int dt1, int dt2) async {
    try {
      final res = await db.query(
        'tmc_points',
        columns: ['date', 'point', 'lat', 'lon', 'speed'],
        where: 'date > ? and date < ?',
        whereArgs: [dt1, dt2],
      );

      final resultList = <Point>[];
      final uniqueDates = <int>{};

      for (final e in res) {
        final point = Point.fromMap(e);
        if (!uniqueDates.contains(point.dt)) {
          uniqueDates.add(point.dt);
          resultList.add(point);
        }
      }

      return resultList;
    } catch (e) {
      throw Exception('Failed to get operation points: $e');
    }
  }

  static Future<void> closeDb() async {
    await _db?.close();
    _db = null;
    curDbPath = '';
  }
}
