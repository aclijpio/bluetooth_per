import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as classic;

import '../core/error/failures.dart';
import 'entities/main_data.dart';
import 'config/device_config.dart';
import 'entities/archive_info.dart';
import 'entities/bluetooth_device.dart';
import 'entities/point.dart';
import 'entities/operation.dart';
import 'repositories/bluetooth_server_repository.dart';
import 'services/web_integration_service.dart';
import 'transport/bluetooth_transport.dart';

/// Основной класс для управления Bluetooth взаимодействием
/// Содержит отдельные методы для каждого этапа работы
class BluetoothManager {
  final BluetoothTransport _transport;
  final BluetoothServerRepository _bluetoothRepository;
  final WebIntegrationService _webService;

  BluetoothManager({
    required classic.FlutterBlueClassic flutterBlueClassic,
    required MainData mainData,
  })  : _transport = BluetoothTransport(flutterBlueClassic),
        _bluetoothRepository = BluetoothServerRepository(
            flutterBlueClassic, BluetoothTransport(flutterBlueClassic)),
        _webService = WebIntegrationService(mainData);

  /// Поиск Bluetooth устройств
  Future<Either<Failure, List<BluetoothDevice>>> scanForDevices() async {
    try {
      print('🔍 [BluetoothManager] Начинаем поиск устройств...');
      final result = await _bluetoothRepository.scanForDevices();

      result.fold(
        (failure) {
          print(
              '❌ [BluetoothManager] Ошибка поиска устройств: ${failure.message}');
        },
        (devices) {
          print('📊 [BluetoothManager] Найдено устройств: ${devices.length}');
          if (devices.isNotEmpty) {
            for (final device in devices) {
              print('✅ [BluetoothManager] ${device.name} (${device.address})');
            }
          } else {
            print('⚠️ [BluetoothManager] Устройства не найдены');
          }
        },
      );

      return result;
    } catch (e) {
      print('❌ [BluetoothManager] Исключение при поиске устройств: $e');
      return Left(BluetoothFailure(message: 'Ошибка поиска устройств: $e'));
    }
  }

  /// Подключение к устройству и обновление архива
  Future<Either<Failure, ArchiveInfo>> connectAndUpdateArchive(
      BluetoothDevice device) async {
    try {
      print(
          '🔗 [BluetoothManager] Подключение к устройству: ${device.name} (${device.address})');
      final result = await _bluetoothRepository.connectAndUpdateArchive(device);

      result.fold(
        (failure) {
          print('❌ [BluetoothManager] Ошибка подключения: ${failure.message}');
        },
        (archiveInfo) {
          print('✅ [BluetoothManager] Архив готов: ${archiveInfo.fileName}');
        },
      );

      return result;
    } catch (e) {
      print('❌ [BluetoothManager] Исключение при подключении: $e');
      return Left(ConnectionFailure(message: 'Ошибка подключения: $e'));
    }
  }

  /// Скачивание архива
  Future<Either<Failure, String>> downloadArchive(
      ArchiveInfo archiveInfo) async {
    try {
      print('📥 [BluetoothManager] Скачивание архива: ${archiveInfo.fileName}');
      final result = await _bluetoothRepository.downloadArchive(archiveInfo);

      result.fold(
        (failure) {
          print('❌ [BluetoothManager] Ошибка скачивания: ${failure.message}');
        },
        (extractedPath) {
          print('✅ [BluetoothManager] Архив извлечен в: $extractedPath');
        },
      );

      return result;
    } catch (e) {
      print('❌ [BluetoothManager] Исключение при скачивании: $e');
      return Left(
          FileOperationFailure(message: 'Ошибка скачивания архива: $e'));
    }
  }

  /// Загрузка операций из архива
  Future<Either<Failure, List<Operation>>> loadOperationsFromArchive(
      String archivePath) async {
    try {
      print('📂 [BluetoothManager] Загрузка операций из архива: $archivePath');

      final loadResult =
          await _webService.loadOperationsFromArchive(archivePath);
      if (loadResult != OperStatus.ok) {
        final error = 'Failed to load operations: $loadResult';
        print('❌ [BluetoothManager] $error');
        return Left(FileOperationFailure(message: error));
      }

      final operations = _webService.getOperations();
      print('📊 [BluetoothManager] Загружено операций: ${operations.length}');

      if (operations.isEmpty) {
        final error = 'No operations found in archive';
        print('❌ [BluetoothManager] $error');
        return Left(FileOperationFailure(message: error));
      }

      return Right(operations);
    } catch (e) {
      print('❌ [BluetoothManager] Исключение при загрузке операций: $e');
      return Left(
          FileOperationFailure(message: 'Ошибка загрузки операций: $e'));
    }
  }

  /// Обработка операций и получение отличающихся точек
  Future<Either<Failure, List<Point>>> processOperations(
      List<Operation> operations) async {
    try {
      print(
          '🔄 [BluetoothManager] Обработка операций (${operations.length} операций)');
      final allDifferentPoints = <Point>[];

      for (int i = 0; i < operations.length; i++) {
        final operation = operations[i];
        print(
            '📋 [BluetoothManager] Обрабатываем операцию ${i + 1}/${operations.length}: ${operation.dt}');

        // Загружаем точки операции
        final pointsResult = await _webService.loadOperationPoints(operation);
        if (pointsResult != OperStatus.ok) {
          print(
              '⚠️ [BluetoothManager] Предупреждение: Не удалось загрузить точки для операции ${operation.dt}: $pointsResult');
          continue;
        }

        // Получаем отличающиеся точки
        final differentPoints = _webService.getDifferentPoints(operation);
        allDifferentPoints.addAll(differentPoints);

        print(
            '✅ [BluetoothManager] Операция ${operation.dt}: найдено ${differentPoints.length} отличающихся точек');
      }

      print(
          '📊 [BluetoothManager] Всего найдено отличающихся точек: ${allDifferentPoints.length}');
      return Right(allDifferentPoints);
    } catch (e) {
      print('❌ [BluetoothManager] Исключение при обработке операций: $e');
      return Left(
          FileOperationFailure(message: 'Ошибка обработки операций: $e'));
    }
  }

  /// Отправка точек на сервер
  Future<Either<Failure, int>> sendPointsToServer(List<Point> points) async {
    try {
      if (points.isEmpty) {
        print('ℹ️ [BluetoothManager] Нет точек для отправки');
        return const Right(200);
      }

      print(
          '📤 [BluetoothManager] Отправка точек на сервер (${points.length} точек)');
      final sendResult = await _webService.sendDifferentPoints(points);

      if (sendResult != 200) {
        print(
            '⚠️ [BluetoothManager] Предупреждение: Не удалось отправить точки на сервер: $sendResult');
        return Left(ConnectionFailure(
            message: 'Ошибка отправки на сервер: $sendResult'));
      } else {
        print(
            '✅ [BluetoothManager] Успешно отправлено ${points.length} точек на сервер');
        return Right(sendResult);
      }
    } catch (e) {
      print('❌ [BluetoothManager] Исключение при отправке точек: $e');
      return Left(ConnectionFailure(message: 'Ошибка отправки точек: $e'));
    }
  }

  /// Отключение от устройства
  Future<Either<Failure, bool>> disconnect() async {
    try {
      print('🔌 [BluetoothManager] Отключение от устройства');
      final result = await _bluetoothRepository.disconnect();

      result.fold(
        (failure) {
          print('❌ [BluetoothManager] Ошибка отключения: ${failure.message}');
        },
        (success) {
          print('✅ [BluetoothManager] Отключение выполнено успешно');
        },
      );

      return result;
    } catch (e) {
      print('❌ [BluetoothManager] Исключение при отключении: $e');
      return Left(ConnectionFailure(message: 'Ошибка отключения: $e'));
    }
  }

  /// Сброс данных операций
  void resetOperationData() {
    print('🧹 [BluetoothManager] Сброс данных операций');
    _webService.resetOperationData();
  }

  /// Освобождение ресурсов
  Future<void> dispose() async {
    print('🧹 [BluetoothManager] Освобождение ресурсов');
    await _transport.dispose();
    resetOperationData();
    print('✅ [BluetoothManager] Ресурсы освобождены');
  }
}
