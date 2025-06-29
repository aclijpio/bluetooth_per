import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as classic;

import '../config/device_config.dart';
import '../entities/archive_info.dart';
import '../entities/bluetooth_device.dart';
import '../protocol/bluetooth_protocol.dart';
import '../services/archive_service.dart';
import '../transport/bluetooth_transport.dart';
import '../../core/error/failures.dart';

/// Репозиторий для работы с Bluetooth сервером
class BluetoothServerRepository {
  final classic.FlutterBlueClassic _flutterBlueClassic;
  final BluetoothTransport _transport;

  BluetoothServerRepository(this._flutterBlueClassic, this._transport);

  /// Поиск устройств по шаблону
  Future<Either<Failure, List<BluetoothDevice>>> scanForDevices() async {
    try {
      print(
          '🔍 [BluetoothServerRepository] Начинаем поиск Bluetooth устройств...');

      // Останавливаем предыдущее сканирование
      _flutterBlueClassic.stopScan();
      print(
          '🔍 [BluetoothServerRepository] Предыдущее сканирование остановлено');

      final devices = <BluetoothDevice>[];
      final completer = Completer<List<BluetoothDevice>>();

      // Подписываемся на результаты сканирования
      final subscription = _flutterBlueClassic.scanResults.listen(
        (classicDevice) {
          print(
              '🔍 [BluetoothServerRepository] Найдено устройство: ${classicDevice.name} (${classicDevice.address})');
          print(
              '🔍 [BluetoothServerRepository] Тип устройства: ${classicDevice.type}');
          print('🔍 [BluetoothServerRepository] RSSI: ${classicDevice.rssi}');

          // Проверяем соответствие паттерну
          if (DeviceConfig.matchesPattern(classicDevice.name)) {
            print(
                '✅ [BluetoothServerRepository] Устройство соответствует паттерну: ${classicDevice.name}');

            // Проверяем, что устройство еще не добавлено
            if (!devices.any((d) => d.address == classicDevice.address)) {
              final device = BluetoothDevice(
                address: classicDevice.address,
                name: classicDevice.name,
              );
              devices.add(device);
              print(
                  '➕ [BluetoothServerRepository] Добавлено устройство: ${device.name} (${device.address})');
            } else {
              print(
                  '⚠️ [BluetoothServerRepository] Устройство уже добавлено: ${classicDevice.name}');
            }
          } else {
            print(
                '❌ [BluetoothServerRepository] Устройство не соответствует паттерну: ${classicDevice.name}');
            print(
                '🔍 [BluetoothServerRepository] Паттерны для поиска: ${DeviceConfig.getPatterns()}');
          }
        },
        onError: (error) {
          print(
              '❌ [BluetoothServerRepository] Ошибка при сканировании: $error');
          completer.completeError(error);
        },
        onDone: () {
          print('🔍 [BluetoothServerRepository] Сканирование завершено');
        },
      );

      // Начинаем сканирование
      print('🔍 [BluetoothServerRepository] Запускаем сканирование...');
      _flutterBlueClassic.startScan();
      print('🔍 [BluetoothServerRepository] Сканирование запущено');

      // Сканируем 15 секунд (увеличиваем время)
      Timer(const Duration(seconds: 15), () {
        print('⏰ [BluetoothServerRepository] Таймаут сканирования (15 секунд)');
        _flutterBlueClassic.stopScan();
        subscription.cancel();

        print('📊 [BluetoothServerRepository] Результаты сканирования:');
        print('   - Всего найдено устройств: ${devices.length}');
        for (final device in devices) {
          print('   - ${device.name} (${device.address})');
        }

        if (devices.isEmpty) {
          print(
              '⚠️ [BluetoothServerRepository] Устройства не найдены. Проверьте:');
          print('   - Включен ли Bluetooth на обоих устройствах');
          print('   - Запущено ли Java приложение');
          print('   - Устройства находятся рядом');
          print('   - Предоставлены ли разрешения на местоположение');
        }

        completer.complete(devices);
      });

      final result = await completer.future;
      print('✅ [BluetoothServerRepository] Поиск устройств завершен успешно');
      return Right(result);
    } catch (e) {
      print('❌ [BluetoothServerRepository] Ошибка при поиске устройств: $e');
      return Left(BluetoothFailure(message: 'Ошибка поиска устройств: $e'));
    }
  }

  /// Подключение к устройству и запрос обновления архива
  Future<Either<Failure, ArchiveInfo>> connectAndUpdateArchive(
      BluetoothDevice device) async {
    try {
      print(
          '🔗 [BluetoothServerRepository] Подключение к устройству: ${device.name} (${device.address})');

      // Подключаемся к устройству
      await _transport.connect(device.address);
      print(
          '✅ [BluetoothServerRepository] Подключение к устройству установлено');

      // Отправляем команду обновления архива
      final updateCommand = BluetoothProtocol.updateArchiveCmd();
      print('📤 [BluetoothServerRepository] Отправляем команду UPDATE_ARCHIVE');
      _transport.sendCommand(updateCommand);
      print('✅ [BluetoothServerRepository] Команда UPDATE_ARCHIVE отправлена');

      // Ждем ответа о готовности архива
      print(
          '⏳ [BluetoothServerRepository] Ожидаем ответ о готовности архива...');
      final archiveInfo = await _waitForArchiveReady();
      print(
          '✅ [BluetoothServerRepository] Получен ответ о готовности архива: ${archiveInfo.fileName}');

      return Right(archiveInfo);
    } catch (e) {
      print(
          '❌ [BluetoothServerRepository] Ошибка при подключении и обновлении архива: $e');
      return Left(ConnectionFailure(message: 'Ошибка подключения: $e'));
    }
  }

  /// Скачивание архива
  Future<Either<Failure, String>> downloadArchive(
      ArchiveInfo archiveInfo) async {
    try {
      print(
          '📥 [BluetoothServerRepository] Начинаем скачивание архива: ${archiveInfo.fileName}');

      // Отправляем команду получения архива
      final getCommand = BluetoothProtocol.getArchiveCmd(archiveInfo.path);
      print(
          '📤 [BluetoothServerRepository] Отправляем команду GET_ARCHIVE для файла: ${archiveInfo.path}');
      _transport.sendCommand(getCommand);
      print('✅ [BluetoothServerRepository] Команда GET_ARCHIVE отправлена');

      // Скачиваем архив
      print('⏳ [BluetoothServerRepository] Скачиваем данные архива...');
      final archiveData = await _downloadArchiveData();
      print(
          '✅ [BluetoothServerRepository] Данные архива получены (${archiveData.length} байт)');

      // Распаковываем архив
      print('📦 [BluetoothServerRepository] Распаковываем архив...');
      final extractedPath = await ArchiveService.extractArchive(
          archiveData, archiveInfo.fileName);
      print('✅ [BluetoothServerRepository] Архив распакован в: $extractedPath');

      return Right(extractedPath);
    } catch (e) {
      print('❌ [BluetoothServerRepository] Ошибка при скачивании архива: $e');
      return Left(
          FileOperationFailure(message: 'Ошибка скачивания архива: $e'));
    }
  }

  /// Отключение от устройства
  Future<Either<Failure, bool>> disconnect() async {
    try {
      print('🔌 [BluetoothServerRepository] Отключаемся от устройства...');
      await _transport.disconnect();
      print('✅ [BluetoothServerRepository] Отключение выполнено успешно');
      return const Right(true);
    } catch (e) {
      print('❌ [BluetoothServerRepository] Ошибка при отключении: $e');
      return Left(ConnectionFailure(message: 'Ошибка отключения: $e'));
    }
  }

  /// Ожидание ответа о готовности архива
  Future<ArchiveInfo> _waitForArchiveReady() async {
    final completer = Completer<ArchiveInfo>();

    final subscription = _transport.bytes.listen(
      (data) {
        print(
            '📨 [BluetoothServerRepository] Получены данные: ${data.length} байт');
        final command = _decodeCommand(data);
        print(
            '📨 [BluetoothServerRepository] Декодированная команда: $command');

        if (command == BluetoothProtocol.CMD_OK) {
          print(
              '✅ [BluetoothServerRepository] Получена команда OK - сервер готов к обновлению');
          // Продолжаем ждать ARCHIVE_READY
        } else if (command == BluetoothProtocol.CMD_UPDATING_ARCHIVE) {
          print(
              '⏳ [BluetoothServerRepository] Получена команда UPDATING_ARCHIVE - сервер обновляет архив');
          // Продолжаем ждать ARCHIVE_READY
        } else if (command.startsWith(BluetoothProtocol.CMD_ARCHIVE_READY)) {
          print('✅ [BluetoothServerRepository] Получена команда ARCHIVE_READY');
          final path = BluetoothProtocol.extractArchiveReadyPath(command);
          if (path != null) {
            print('📁 [BluetoothServerRepository] Путь к архиву: $path');
            completer.complete(ArchiveInfo.fromPath(path));
          } else {
            print(
                '❌ [BluetoothServerRepository] Не удалось извлечь путь из команды ARCHIVE_READY');
            completer.completeError(
                Exception('Invalid ARCHIVE_READY command format'));
          }
        } else if (command.startsWith(BluetoothProtocol.CMD_ERROR)) {
          print('❌ [BluetoothServerRepository] Получена команда ERROR');
          final error = BluetoothProtocol.extractErrorMessage(command);
          print('❌ [BluetoothServerRepository] Сообщение об ошибке: $error');
          completer.completeError(Exception(error ?? 'Unknown error'));
        } else {
          print('⚠️ [BluetoothServerRepository] Неизвестная команда: $command');
        }
      },
      onError: (error) {
        print(
            '❌ [BluetoothServerRepository] Ошибка при получении данных: $error');
        completer.completeError(error);
      },
    );

    // Таймаут 30 секунд
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        print(
            '⏰ [BluetoothServerRepository] Таймаут ожидания ответа о готовности архива (30 секунд)');
        completer.completeError(Exception('Timeout waiting for archive ready'));
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

  /// Скачивание данных архива
  Future<Uint8List> _downloadArchiveData() async {
    final completer = Completer<Uint8List>();
    final buffer = <int>[];

    print('📥 [BluetoothServerRepository] Начинаем получение данных архива...');

    final subscription = _transport.bytes.listen(
      (data) {
        print(
            '📨 [BluetoothServerRepository] Получен блок данных: ${data.length} байт');
        buffer.addAll(data);
        print(
            '📊 [BluetoothServerRepository] Общий размер полученных данных: ${buffer.length} байт');
      },
      onError: (error) {
        print(
            '❌ [BluetoothServerRepository] Ошибка при получении данных архива: $error');
        completer.completeError(error);
      },
      onDone: () {
        print(
            '✅ [BluetoothServerRepository] Получение данных архива завершено');
      },
    );

    // Таймаут 60 секунд для скачивания
    Timer(const Duration(seconds: 60), () {
      if (!completer.isCompleted) {
        print(
            '⏰ [BluetoothServerRepository] Таймаут скачивания архива (60 секунд)');
        print(
            '📊 [BluetoothServerRepository] Итоговый размер полученных данных: ${buffer.length} байт');
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
            '❌ [BluetoothServerRepository] Недостаточно данных для декодирования команды: ${data.length} байт');
        return '';
      }

      final length = (data[0] << 8) | data[1];
      print('📏 [BluetoothServerRepository] Длина команды: $length байт');

      if (data.length < 2 + length) {
        print(
            '❌ [BluetoothServerRepository] Неполные данные команды: ожидалось ${2 + length}, получено ${data.length}');
        return '';
      }

      final commandBytes = data.sublist(2, 2 + length);
      final command = utf8.decode(commandBytes);
      print('📝 [BluetoothServerRepository] Декодированная команда: $command');
      return command;
    } catch (e) {
      print('❌ [BluetoothServerRepository] Ошибка декодирования команды: $e');
      return '';
    }
  }
}
