import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as classic;

import '../core/error/failures.dart';
import 'entities/main_data.dart';
import 'entities/archive_info.dart';
import 'entities/bluetooth_device.dart';
import 'entities/point.dart';
import 'entities/operation.dart';
import 'config/device_config.dart';
import 'transport/bluetooth_transport.dart';
import 'services/archive_service.dart';
import 'services/web_integration_service.dart';
import 'protocol/bluetooth_protocol.dart';

/// Полный workflow для работы с Bluetooth устройствами
/// Объединяет все этапы от поиска устройств до отправки данных на сервер
class BluetoothWorkflow {
  final classic.FlutterBlueClassic _flutterBlueClassic;
  final BluetoothTransport _transport;
  final WebIntegrationService _webService;
  final MainData _mainData;

  /// Адрес последнего успешного подключения – нужен для переподключения,
  /// если сервер разорвал соединение между ARCHIVE_READY и GET_ARCHIVE.
  String? _lastConnectedAddress;

  BluetoothWorkflow({
    required classic.FlutterBlueClassic flutterBlueClassic,
    required MainData mainData,
  })  : _flutterBlueClassic = flutterBlueClassic,
        _transport = BluetoothTransport(flutterBlueClassic),
        _mainData = mainData,
        _webService = WebIntegrationService(mainData);

  /// Полный процесс от поиска устройств до отправки точек на сервер
  Future<Either<Failure, List<Point>>> executeFullWorkflow() async {
    try {
      print('🚀 [BluetoothWorkflow] Начинаем полный workflow...');

      // Шаг 1: Поиск устройств
      print('🔍 [BluetoothWorkflow] Шаг 1: Поиск Bluetooth устройств');
      final scanResult = await _scanForDevices();
      if (scanResult.isLeft()) {
        final failure =
            scanResult.fold((l) => l, (r) => throw Exception('Unexpected'));
        print(
            '❌ [BluetoothWorkflow] Ошибка поиска устройств: ${failure.message}');
        return Left(failure);
      }

      final devices =
          scanResult.fold((l) => throw Exception('Unexpected'), (r) => r);
      print('📊 [BluetoothWorkflow] Найдено устройств: ${devices.length}');

      if (devices.isEmpty) {
        final error =
            'No devices found matching patterns: ${DeviceConfig.getPatterns()}';
        print('❌ [BluetoothWorkflow] $error');
        return Left(BluetoothFailure(message: error));
      }

      // Берем первое найденное устройство
      final device = devices.first;
      print(
          '✅ [BluetoothWorkflow] Выбрано устройство: ${device.name} (${device.address})');

      // Шаг 2: Подключение и обновление архива
      print(
          '🔗 [BluetoothWorkflow] Шаг 2: Подключение к устройству и обновление архива');
      final connectResult = await _connectAndUpdateArchive(device);
      if (connectResult.isLeft()) {
        final failure =
            connectResult.fold((l) => l, (r) => throw Exception('Unexpected'));
        print('❌ [BluetoothWorkflow] Ошибка подключения: ${failure.message}');
        return Left(failure);
      }

      final archiveInfo =
          connectResult.fold((l) => throw Exception('Unexpected'), (r) => r);
      print('✅ [BluetoothWorkflow] Архив готов: ${archiveInfo.fileName}');

      // Шаг 3: Скачивание архива
      print('📥 [BluetoothWorkflow] Шаг 3: Скачивание архива');
      final downloadResult = await _downloadArchive(archiveInfo);
      if (downloadResult.isLeft()) {
        final failure =
            downloadResult.fold((l) => l, (r) => throw Exception('Unexpected'));
        print(
            '❌ [BluetoothWorkflow] Ошибка скачивания архива: ${failure.message}');
        return Left(failure);
      }

      final extractedPath =
          downloadResult.fold((l) => throw Exception('Unexpected'), (r) => r);
      print('✅ [BluetoothWorkflow] Архив извлечен в: $extractedPath');

      // Шаг 4: Загрузка операций из архива
      print('📂 [BluetoothWorkflow] Шаг 4: Загрузка операций из архива');
      final loadResult =
          await _webService.loadOperationsFromArchive(extractedPath);
      if (loadResult != OperStatus.ok) {
        final error = 'Failed to load operations: $loadResult';
        print('❌ [BluetoothWorkflow] $error');
        return Left(FileOperationFailure(message: error));
      }

      final operations = _webService.getOperations();
      print('📊 [BluetoothWorkflow] Загружено операций: ${operations.length}');

      if (operations.isEmpty) {
        final error = 'No operations found in archive';
        print('❌ [BluetoothWorkflow] $error');
        return Left(FileOperationFailure(message: error));
      }

      // Шаг 5: Обработка каждой операции
      print('🔄 [BluetoothWorkflow] Шаг 5: Обработка операций');
      final allDifferentPoints = <Point>[];

      for (int i = 0; i < operations.length; i++) {
        final operation = operations[i];
        print(
            '📋 [BluetoothWorkflow] Обрабатываем операцию ${i + 1}/${operations.length}: ${operation.dt}');

        // Загружаем точки операции
        final pointsResult = await _webService.loadOperationPoints(operation);
        if (pointsResult != OperStatus.ok) {
          print(
              '⚠️ [BluetoothWorkflow] Предупреждение: Не удалось загрузить точки для операции ${operation.dt}: $pointsResult');
          continue;
        }

        // Получаем отличающиеся точки
        final differentPoints = _webService.getDifferentPoints(operation);
        allDifferentPoints.addAll(differentPoints);

        print(
            '✅ [BluetoothWorkflow] Операция ${operation.dt}: найдено ${differentPoints.length} отличающихся точек');
      }

      // Шаг 6: Отключение от устройства
      print('🔌 [BluetoothWorkflow] Шаг 6: Отключение от устройства');
      await _disconnect();
      print('✅ [BluetoothWorkflow] Отключение выполнено');

      // Шаг 7: Отправка отличающихся точек на сервер
      if (allDifferentPoints.isNotEmpty) {
        print(
            '📤 [BluetoothWorkflow] Шаг 7: Отправка точек на сервер (${allDifferentPoints.length} точек)');
        final sendResult =
            await _webService.sendDifferentPoints(allDifferentPoints);
        if (sendResult != 200) {
          print(
              '⚠️ [BluetoothWorkflow] Предупреждение: Не удалось отправить точки на сервер: $sendResult');
        } else {
          print(
              '✅ [BluetoothWorkflow] Успешно отправлено ${allDifferentPoints.length} точек на сервер');
        }
      } else {
        print('ℹ️ [BluetoothWorkflow] Нет отличающихся точек для отправки');
      }

      print('🎉 [BluetoothWorkflow] Полный workflow завершен успешно!');
      return Right(allDifferentPoints);
    } catch (e) {
      print('❌ [BluetoothWorkflow] Исключение в полном workflow: $e');
      return Left(BluetoothFailure(message: e.toString()));
    } finally {
      print('🧹 [BluetoothWorkflow] Очистка ресурсов');
      await _disconnect();
      _webService.resetOperationData();
      print('✅ [BluetoothWorkflow] Ресурсы очищены');
    }
  }

  /// Поиск Bluetooth устройств
  Future<Either<Failure, List<BluetoothDevice>>> _scanForDevices() async {
    try {
      print('🔍 [BluetoothWorkflow] Начинаем поиск устройств...');
      final completer = Completer<List<BluetoothDevice>>();
      final devices = <BluetoothDevice>[];
      final seenDevices = <String>{};

      final subscription = _flutterBlueClassic.scanResults.listen(
        (classicDevice) {
          print(
              '📡 [BluetoothWorkflow] Найдено устройство: ${classicDevice.name} (${classicDevice.address})');

          // Проверяем, что устройство еще не обработано
          if (seenDevices.contains(classicDevice.address)) {
            return;
          }
          seenDevices.add(classicDevice.address);

          // Проверяем соответствие паттерну
          if (classicDevice.name != null &&
              classicDevice.name != "null" &&
              DeviceConfig.matchesPattern(classicDevice.name)) {
            print(
                '✅ [BluetoothWorkflow] Устройство соответствует паттерну: ${classicDevice.name}');

            // Проверяем, что устройство еще не добавлено
            if (!devices.any((d) => d.address == classicDevice.address)) {
              final device = BluetoothDevice(
                address: classicDevice.address,
                name: classicDevice.name,
              );
              devices.add(device);
              print(
                  '➕ [BluetoothWorkflow] Добавлено устройство: ${device.name} (${device.address})');
            }
          }
        },
        onError: (error) {
          print('❌ [BluetoothWorkflow] Ошибка при сканировании: $error');
          completer.completeError(error);
        },
        onDone: () {
          print('🔍 [BluetoothWorkflow] Сканирование завершено');
        },
      );

      // Начинаем сканирование
      print('🔍 [BluetoothWorkflow] Запускаем сканирование на 60 секунд...');
      _flutterBlueClassic.startScan();

      // Сканируем 60 секунд
      Timer(const Duration(seconds: 60), () {
        print('⏰ [BluetoothWorkflow] Таймаут сканирования (60 секунд)');
        _flutterBlueClassic.stopScan();
        subscription.cancel();

        print('📊 [BluetoothWorkflow] Результаты сканирования:');
        print('   - Всего найдено уникальных устройств: ${seenDevices.length}');
        print('   - Устройств, соответствующих паттерну: ${devices.length}');

        if (devices.isNotEmpty) {
          for (final device in devices) {
            print('   ✅ ${device.name} (${device.address})');
          }
        } else {
          print('   ❌ Устройства с именем "Quantor" не найдены');
        }

        completer.complete(devices);
      });

      final result = await completer.future;
      print('✅ [BluetoothWorkflow] Поиск устройств завершен');
      return Right(result);
    } catch (e) {
      print('❌ [BluetoothWorkflow] Ошибка при поиске устройств: $e');
      return Left(BluetoothFailure(message: 'Ошибка поиска устройств: $e'));
    }
  }

  /// Подключение к устройству и обновление архива
  Future<Either<Failure, ArchiveInfo>> _connectAndUpdateArchive(
      BluetoothDevice device) async {
    try {
      print(
          '🔗 [BluetoothWorkflow] Подключение к устройству: ${device.name} (${device.address})');

      // Подключаемся к устройству
      await _transport.connect(device.address);
      _lastConnectedAddress = device.address;
      print('✅ [BluetoothWorkflow] Подключение к устройству установлено');

      // Отправляем команду обновления архива
      final updateCommand = BluetoothProtocol.updateArchiveCmd();
      print('📤 [BluetoothWorkflow] Отправляем команду UPDATE_ARCHIVE');
      _transport.sendCommand(updateCommand);
      print('✅ [BluetoothWorkflow] Команда UPDATE_ARCHIVE отправлена');

      // Ждем, пока сервер подготовит архив и пришлёт ARCHIVE_READY
      print('⏳ [BluetoothWorkflow] Ожидаем ARCHIVE_READY от сервера...');
      final archiveInfo = await _waitForArchiveReady();
      print(
          '✅ [BluetoothWorkflow] ARCHIVE_READY получен: ${archiveInfo.fileName}');

      // Убеждаемся, что соединение ещё активно. Если нет – переподключаемся.
      if (!_transport.isConnected) {
        print(
            '🔄 [BluetoothWorkflow] Соединение потеряно перед GET_ARCHIVE – переподключаемся');
        await _transport.connect(_lastConnectedAddress!);
        print('✅ [BluetoothWorkflow] Переподключение выполнено');
      }

      // Отправляем GET_ARCHIVE (первоначально или после переподключения)
      final getArchiveCmd = BluetoothProtocol.getArchiveCmd(archiveInfo.path);
      print('📤 [BluetoothWorkflow] Отправляем GET_ARCHIVE');
      _transport.sendCommand(getArchiveCmd);
      print('✅ [BluetoothWorkflow] GET_ARCHIVE отправлен');

      return Right(archiveInfo);
    } catch (e) {
      print(
          '❌ [BluetoothWorkflow] Ошибка при подключении и обновлении архива: $e');
      return Left(ConnectionFailure(message: 'Ошибка подключения: $e'));
    }
  }

  /// Скачивание архива
  Future<Either<Failure, String>> _downloadArchive(
      ArchiveInfo archiveInfo) async {
    try {
      print(
          '📥 [BluetoothWorkflow] Начинаем скачивание архива: ${archiveInfo.fileName}');

      // Если сервер успел закрыть соединение, переподключаемся и повторно
      // отправляем команду GET_ARCHIVE.
      bool resentGetArchive = false;
      if (!_transport.isConnected) {
        if (_lastConnectedAddress == null) {
          throw StateError('Неизвестно, к какому устройству переподключаться');
        }

        print(
            '🔄 [BluetoothWorkflow] Переподключаемся к $_lastConnectedAddress');
        await _transport.connect(_lastConnectedAddress!);
        print('✅ [BluetoothWorkflow] Переподключение выполнено');

        final getArchiveCmd = BluetoothProtocol.getArchiveCmd(archiveInfo.path);
        print('📤 [BluetoothWorkflow] Повторно отправляем GET_ARCHIVE');
        _transport.sendCommand(getArchiveCmd);
        resentGetArchive = true;
      }

      if (!resentGetArchive) {
        print('ℹ️ [BluetoothWorkflow] GET_ARCHIVE уже был отправлен ранее');
      }

      // Скачиваем данные архива
      print('📥 [BluetoothWorkflow] Скачиваем данные архива...');
      final archiveData = await _downloadArchiveData();
      print(
          '✅ [BluetoothWorkflow] Данные архива получены (${archiveData.length} байт)');

      // Распаковываем архив
      print('📦 [BluetoothWorkflow] Распаковываем архив...');
      final extractedPath = await ArchiveService.extractArchive(
          archiveData, archiveInfo.fileName);
      print('✅ [BluetoothWorkflow] Архив распакован в: $extractedPath');

      return Right(extractedPath);
    } catch (e) {
      print('❌ [BluetoothWorkflow] Ошибка при скачивании архива: $e');
      return Left(
          FileOperationFailure(message: 'Ошибка скачивания архива: $e'));
    } finally {
      await _transport.disconnect();
      _lastConnectedAddress = null;
    }
  }

  /// Отключение от устройства
  Future<void> _disconnect() async {
    try {
      print('🔌 [BluetoothWorkflow] Отключаемся от устройства...');
      await _transport.disconnect();
      print('✅ [BluetoothWorkflow] Отключение выполнено успешно');
    } catch (e) {
      print('❌ [BluetoothWorkflow] Ошибка при отключении: $e');
    }
  }

  /// Скачивание данных архива
  Future<Uint8List> _downloadArchiveData() async {
    final completer = Completer<Uint8List>();
    final buffer = <int>[];

    print('📥 [BluetoothWorkflow] Начинаем получение данных архива...');

    final subscription = _transport.bytes.listen(
      (data) {
        print(
            '📨 [BluetoothWorkflow] Получен блок данных: ${data.length} байт');
        buffer.addAll(data);
        print(
            '📊 [BluetoothWorkflow] Общий размер полученных данных: ${buffer.length} байт');
      },
      onError: (error) {
        print(
            '❌ [BluetoothWorkflow] Ошибка при получении данных архива: $error');
        completer.completeError(error);
      },
      onDone: () {
        print('✅ [BluetoothWorkflow] Получение данных архива завершено');
        if (!completer.isCompleted) {
          completer.complete(Uint8List.fromList(buffer));
        }
      },
    );

    // Таймаут 60 секунд для скачивания
    Timer(const Duration(seconds: 60), () {
      if (!completer.isCompleted) {
        print('⏰ [BluetoothWorkflow] Таймаут скачивания архива (60 секунд)');
        print(
            '📊 [BluetoothWorkflow] Итоговый размер полученных данных: ${buffer.length} байт');
        completer.complete(Uint8List.fromList(buffer));
      }
    });

    try {
      final result = await completer.future;
      subscription.cancel();
      return result;
    } catch (e) {
      subscription.cancel();
      rethrow;
    }
  }

  /// Декодирование команды из байтов
  String _decodeCommand(List<int> data) {
    try {
      if (data.length < 2) {
        print(
            '❌ [BluetoothWorkflow] Недостаточно данных для декодирования команды: ${data.length} байт');
        return '';
      }

      final length = (data[0] << 8) | data[1];
      print('📏 [BluetoothWorkflow] Длина команды: $length байт');

      if (data.length < 2 + length) {
        print(
            '❌ [BluetoothWorkflow] Неполные данные команды: ожидалось ${2 + length}, получено ${data.length}');
        return '';
      }

      final commandBytes = data.sublist(2, 2 + length);
      final command = String.fromCharCodes(commandBytes);
      print('📝 [BluetoothWorkflow] Декодированная команда: $command');
      return command;
    } catch (e) {
      print('❌ [BluetoothWorkflow] Ошибка декодирования команды: $e');
      return '';
    }
  }

  /// Освобождение ресурсов
  Future<void> dispose() async {
    await _transport.dispose();
  }

  // ---------------------- WAIT FOR ARCHIVE READY ----------------------
  Future<ArchiveInfo> _waitForArchiveReady() async {
    final completer = Completer<ArchiveInfo>();

    final subscription = _transport.bytes.listen(
      (data) {
        final cmd = _decodeCommand(data);
        if (cmd.startsWith(BluetoothProtocol.CMD_ARCHIVE_READY)) {
          final path = BluetoothProtocol.extractArchiveReadyPath(cmd);
          if (path != null) {
            completer.complete(ArchiveInfo.fromPath(path));
          } else {
            completer.completeError(
                Exception('Invalid ARCHIVE_READY command format'));
          }
        } else if (cmd.startsWith(BluetoothProtocol.CMD_ERROR)) {
          completer.completeError(
              Exception(BluetoothProtocol.extractErrorMessage(cmd) ?? 'error'));
        }
        // другие команды игнорируем
      },
      onError: completer.completeError,
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Connection closed before ready'));
        }
      },
      cancelOnError: true,
    );

    // safety timeout
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Timeout waiting for ARCHIVE_READY'));
      }
    });

    try {
      final result = await completer.future;
      await subscription.cancel();
      return result;
    } finally {
      await subscription.cancel();
    }
  }
}
