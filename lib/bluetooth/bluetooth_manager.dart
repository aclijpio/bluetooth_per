import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as classic;

import '../core/error/failures.dart';
import 'entities/main_data.dart';
import 'config/device_config.dart';
import 'entities/archive_info.dart';
import 'entities/bluetooth_device.dart';
import 'entities/point.dart';
import 'repositories/bluetooth_server_repository.dart';
import 'services/web_integration_service.dart';
import 'transport/bluetooth_transport.dart';

/// Основной класс для управления Bluetooth взаимодействием
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

  /// Полный flow работы с Bluetooth сервером
  Future<Either<Failure, List<Point>>> executeFullFlow() async {
    try {
      print(
          '🚀 [BluetoothManager] Начинаем полный flow работы с Bluetooth сервером');

      // 1. Поиск устройств
      print('🔍 [BluetoothManager] Шаг 1: Поиск Bluetooth устройств');
      final scanResult = await _bluetoothRepository.scanForDevices();
      if (scanResult.isLeft()) {
        final failure =
            scanResult.fold((l) => l, (r) => throw Exception('Unexpected'));
        print(
            '❌ [BluetoothManager] Ошибка поиска устройств: ${failure.message}');
        return Left(failure);
      }

      final devices =
          scanResult.fold((l) => throw Exception('Unexpected'), (r) => r);
      print('📊 [BluetoothManager] Найдено устройств: ${devices.length}');

      if (devices.isEmpty) {
        final error =
            'No devices found matching patterns: ${DeviceConfig.getPatterns()}';
        print('❌ [BluetoothManager] $error');
        return Left(BluetoothFailure(message: error));
      }

      // Берем первое найденное устройство
      final device = devices.first;
      print(
          '✅ [BluetoothManager] Выбрано устройство: ${device.name} (${device.address})');

      // 2. Подключение и обновление архива
      print(
          '🔗 [BluetoothManager] Шаг 2: Подключение к устройству и обновление архива');
      final connectResult =
          await _bluetoothRepository.connectAndUpdateArchive(device);
      if (connectResult.isLeft()) {
        final failure =
            connectResult.fold((l) => l, (r) => throw Exception('Unexpected'));
        print('❌ [BluetoothManager] Ошибка подключения: ${failure.message}');
        return Left(failure);
      }

      final archiveInfo =
          connectResult.fold((l) => throw Exception('Unexpected'), (r) => r);
      print('✅ [BluetoothManager] Архив готов: ${archiveInfo.fileName}');

      // 3. Скачивание архива
      print('📥 [BluetoothManager] Шаг 3: Скачивание архива');
      final downloadResult =
          await _bluetoothRepository.downloadArchive(archiveInfo);
      if (downloadResult.isLeft()) {
        final failure =
            downloadResult.fold((l) => l, (r) => throw Exception('Unexpected'));
        print(
            '❌ [BluetoothManager] Ошибка скачивания архива: ${failure.message}');
        return Left(failure);
      }

      final extractedPath =
          downloadResult.fold((l) => throw Exception('Unexpected'), (r) => r);
      print('✅ [BluetoothManager] Архив извлечен в: $extractedPath');

      // 4. Загрузка операций из архива
      print('📂 [BluetoothManager] Шаг 4: Загрузка операций из архива');
      final loadResult =
          await _webService.loadOperationsFromArchive(extractedPath);
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

      // 5. Обработка каждой операции
      print('🔄 [BluetoothManager] Шаг 5: Обработка операций');
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

      // 6. Отключение от устройства
      print('🔌 [BluetoothManager] Шаг 6: Отключение от устройства');
      await _bluetoothRepository.disconnect();
      print('✅ [BluetoothManager] Отключение выполнено');

      // 7. Отправка отличающихся точек на сервер
      if (allDifferentPoints.isNotEmpty) {
        print(
            '📤 [BluetoothManager] Шаг 7: Отправка точек на сервер (${allDifferentPoints.length} точек)');
        final sendResult =
            await _webService.sendDifferentPoints(allDifferentPoints);
        if (sendResult != 200) {
          print(
              '⚠️ [BluetoothManager] Предупреждение: Не удалось отправить точки на сервер: $sendResult');
        } else {
          print(
              '✅ [BluetoothManager] Успешно отправлено ${allDifferentPoints.length} точек на сервер');
        }
      } else {
        print('ℹ️ [BluetoothManager] Нет отличающихся точек для отправки');
      }

      print('🎉 [BluetoothManager] Полный flow завершен успешно!');
      return Right(allDifferentPoints);
    } catch (e) {
      print('❌ [BluetoothManager] Исключение в полном flow: $e');
      return Left(BluetoothFailure(message: e.toString()));
    } finally {
      print('🧹 [BluetoothManager] Очистка ресурсов');
      // Очищаем ресурсы
      await _bluetoothRepository.disconnect();
      _webService.resetOperationData();
      print('✅ [BluetoothManager] Ресурсы очищены');
    }
  }

  /// Поиск устройств
  Future<Either<Failure, List<BluetoothDevice>>> scanForDevices() async {
    return await _bluetoothRepository.scanForDevices();
  }

  /// Подключение к устройству и обновление архива
  Future<Either<Failure, ArchiveInfo>> connectAndUpdateArchive(
      BluetoothDevice device) async {
    return await _bluetoothRepository.connectAndUpdateArchive(device);
  }

  /// Скачивание архива
  Future<Either<Failure, String>> downloadArchive(
      ArchiveInfo archiveInfo) async {
    return await _bluetoothRepository.downloadArchive(archiveInfo);
  }

  /// Отключение от устройства
  Future<Either<Failure, bool>> disconnect() async {
    return await _bluetoothRepository.disconnect();
  }

  /// Освобождение ресурсов
  Future<void> dispose() async {
    await _transport.dispose();
  }
}
