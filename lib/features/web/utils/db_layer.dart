import 'dart:convert';
import 'dart:io' show Platform, File;

import 'package:bluetooth_per/core/data/source/device_info.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import 'package:bluetooth_per/core/data/source/point.dart';
import 'package:bluetooth_per/core/utils/log_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as desktop;

class DbLayer {
  static Database? _db;
  static String curDbPath = '';

  static Future<Database> getDb(String newPath) async {
    await LogManager.database('DB', 'Запрос подключения к БД: $newPath');

    if (_db != null) {
      await LogManager.database(
          'DB', 'Закрываем предыдущее подключение к БД: $curDbPath');
      await _db?.close();
      _db = null;
      curDbPath = '';
    }

    if (_db != null) {
      await LogManager.database(
          'DB', 'Используем существующее подключение к БД');
      return _db!;
    }

    try {
      await LogManager.database(
          'DB', 'Инициализируем новое подключение к БД: $newPath');

      // Проверяем существование файла
      final file = File(newPath);
      if (!await file.exists()) {
        throw Exception('Файл БД не существует: $newPath');
      }

      final fileSize = await file.length();
      await LogManager.database('DB', 'Размер файла БД: $fileSize байт');

      _db = await initDb(newPath);
      curDbPath = newPath;

      await LogManager.database(
          'DB', 'БД успешно открыта и готова к использованию');
      return _db!;
    } catch (e) {
      await LogManager.database(
          'DB', 'Не удалось инициализировать БД: $e', LogLevel.error);
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
    await LogManager.database(
        'DB', 'Запрашиваем информацию об устройстве из БД');

    try {
/*      final res =
          await db.query('tmc_agregat', columns: ['serNumber', 'stNumber']);
      return res.isEmpty
          ? DeviceInfo(serialNum: 'N\\A', gosNum: 'N\\A')
          : DeviceInfo.fromMap(res.first);*/

      await LogManager.database('DB', 'Выполняем запрос к таблице tmc_config');

      final res = await db.query('tmc_config',
          columns: ['config'], where: 'record_type = 1');

      await LogManager.database(
          'DB', 'Запрос к tmc_config выполнен, найдено записей: ${res.length}');

      if (res.isEmpty) {
        await LogManager.database(
            'DB', 'Конфигурация не найдена в БД', LogLevel.error);
        throw Exception('Configuration not found in database');
      }

      await LogManager.database('DB', 'Парсим JSON конфигурацию из БД');
      final configJson = res.first['config'] as String;
      final Map<String, dynamic> config = json.decode(configJson);

      final ktaSerial = config['kta_Serial']?.toString() ?? 'N/A';
      final stateNumber = config['state_Number']?.toString() ?? 'N/A';

      await LogManager.database('DB',
          'Информация об устройстве получена: serial=$ktaSerial, state=$stateNumber');

      return DeviceInfo(serialNum: ktaSerial, gosNum: stateNumber);
    } catch (e) {
      await LogManager.database(
          'DB', 'Ошибка при запросе конфигурации из БД: $e', LogLevel.error);
      throw Exception('Failed to get device info: $e');
    }
  }

  static Future<List<Operation>> getOperationList(Database db) async {
    // Убираем информационный лог

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
      await LogManager.database(
          'DB', 'Операции не найдены в БД', LogLevel.warning);
      return [];
    } else {
      final operations = res.map((e) => Operation.fromMap(e)).toList();
      return operations;
    }
  }

  static Future<List<Point>> getOperationPoints(
      Database db, int dt1, int dt2) async {
    await LogManager.database(
        'DB', 'Запрашиваем точки для операции dt1=$dt1, dt2=$dt2');

    var totalRes = await db.query('tmc_points', columns: ['COUNT(*) as count']);
    final totalPoints = totalRes.first['count'] as int;
    await LogManager.database(
        'DB', 'Общее количество точек в БД: $totalPoints');

    var res = await db.query(
      'tmc_points',
      columns: ['date', 'point', 'lat', 'lon', 'speed'],
      where: 'date > ? and date < ?',
      whereArgs: [dt1, dt2],
    );

    await LogManager.database('DB',
        'Найдено ${res.length} точек в БД для операции dt1=$dt1, dt2=$dt2');

    if (res.isEmpty) {
      await LogManager.database(
          'DB', 'Точки не найдены для операции dt1=$dt1, dt2=$dt2');
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

      await LogManager.database('DB',
          'После дедупликации осталось ${resultList.length} уникальных точек для операции dt1=$dt1, dt2=$dt2');
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

  static Future<void> resetConnection() async {
    await LogManager.database('DB', 'Принудительный сброс подключения к БД');
    await _db?.close();
    _db = null;
    curDbPath = '';
  }
}
