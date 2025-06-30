import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as classic;
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

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

  /// Адрес устройства, к которому устанавливалось последнее успешное подключение.
  /// Используется для автоматического переподключения, если соединение прервалось
  /// до отправки очередной команды.
  String? _lastConnectedAddress;

  BluetoothServerRepository(this._flutterBlueClassic, this._transport);

  /// Поиск устройств по шаблону
  Future<Either<Failure, List<BluetoothDevice>>> scanForDevices() async {
    try {
      print(
          '🔍 [BluetoothServerRepository] Начинаем поиск Bluetooth устройств...');

      final devices = <BluetoothDevice>[];

      // ------------------- Collect already bonded (paired) devices -------------------
      try {
        print(
            '🔍 [BluetoothServerRepository] Проверяем спаренные устройства...');
        final bonded = await _flutterBlueClassic.bondedDevices ??
            <classic.BluetoothDevice>[];

        for (final d in bonded) {
          if (d.name != null &&
              d.name != "null" &&
              DeviceConfig.matchesPattern(d.name)) {
            print(
                '✅ [BluetoothServerRepository] Спаренное устройство соответствует паттерну: ${d.name}');

            // Проверяем, что устройство ещё не было добавлено
            if (!devices.any((e) => e.address == d.address)) {
              devices.add(BluetoothDevice(address: d.address, name: d.name));
              print(
                  '➕ [BluetoothServerRepository] Добавлено спаренное устройство: ${d.name} (${d.address})');
            }
          }
        }

        print(
            'ℹ️ [BluetoothServerRepository] Найдено спаренных устройств: ${bonded.length}');
      } catch (e) {
        print(
            '⚠️ [BluetoothServerRepository] Не удалось получить список спаренных устройств: $e');
      }

      // Останавливаем предыдущее сканирование
      _flutterBlueClassic.stopScan();
      print(
          '🔍 [BluetoothServerRepository] Предыдущее сканирование остановлено');

      final completer = Completer<List<BluetoothDevice>>();

      final startTime = DateTime.now();

      late StreamSubscription subscription;
      subscription = _flutterBlueClassic.scanResults.listen(
        (classicDevice) async {
          print(
              '🔍 [BluetoothServerRepository] Найдено устройство: ${classicDevice.name} (${classicDevice.address})');

          // фильтр по именам
          if (classicDevice.name != null &&
              classicDevice.name != "null" &&
              DeviceConfig.matchesPattern(classicDevice.name)) {
            if (!devices.any((d) => d.address == classicDevice.address)) {
              devices.add(BluetoothDevice(
                  address: classicDevice.address, name: classicDevice.name));
              print(
                  '➕ [BluetoothServerRepository] Добавлено устройство: ${classicDevice.name} (${classicDevice.address})');
            }
          }

          // Если хотя бы одно устройство найдено и прошло ≥3 с с начала — завершаем скан
          final elapsed = DateTime.now().difference(startTime).inSeconds;
          if (devices.isNotEmpty && elapsed >= 3) {
            print(
                '✅ [BluetoothServerRepository] Достаточно данных, останавливаем сканирование');
            await _flutterBlueClassic.stopScan();
            await subscription.cancel();
            if (!completer.isCompleted) completer.complete(devices);
          }
        },
        onError: (error) {
          print(
              '❌ [BluetoothServerRepository] Ошибка при сканировании: $error');
          if (!completer.isCompleted) completer.completeError(error);
        },
      );

      // Начинаем сканирование
      print('🔍 [BluetoothServerRepository] Запускаем сканирование...');
      _flutterBlueClassic.startScan();
      print('🔍 [BluetoothServerRepository] Сканирование запущено');

      // safety-таймаут на случай, если устройств нет
      Timer(const Duration(seconds: 20), () async {
        print('⏰ [BluetoothServerRepository] Таймаут сканирования (20 секунд)');
        await _flutterBlueClassic.stopScan();
        await subscription.cancel();
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
      _lastConnectedAddress = device.address;
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

      // Если соединение было разорвано сервером после ARCHIVE_READY,
      // выполняем автоматическое переподключение перед отправкой GET_ARCHIVE.
      if (!_transport.isConnected) {
        if (_lastConnectedAddress == null) {
          throw StateError(
              'Неизвестно, к какому устройству подключаться для повторного соединения');
        }

        print(
            '🔄 [BluetoothServerRepository] Соединение потеряно – пытаемся переподключиться к ${_lastConnectedAddress!}');
        await _transport.connect(_lastConnectedAddress!);
        print('✅ [BluetoothServerRepository] Переподключились успешно');
      }

      // Отправляем команду получения архива
      final getCommand = BluetoothProtocol.getArchiveCmd(archiveInfo.path);
      print(
          '📤 [BluetoothServerRepository] Отправляем команду GET_ARCHIVE для файла: ${archiveInfo.path}');
      try {
        _transport.sendCommand(getCommand);
      } catch (e) {
        print('⚠️ [BluetoothServerRepository] Ошибка отправки GET_ARCHIVE: $e');
        print(
            '🔄 [BluetoothServerRepository] Пытаемся переподключиться и повторить');
        await _transport.disconnect();
        await _transport.connect(_lastConnectedAddress!);
        _transport.sendCommand(getCommand);
      }
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
      _lastConnectedAddress = null;
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

        if (command == BluetoothProtocol.CMD_UPDATING_ARCHIVE) {
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

    late StreamSubscription subscription;
    Timer? timeoutTimer;

    void completeIfNot() {
      if (!completer.isCompleted) {
        completer.complete(Uint8List.fromList(buffer));
      }
    }

    const idle = Duration(seconds: 2);
    Timer? idleTimer;

    void resetIdle() {
      idleTimer?.cancel();
      idleTimer = Timer(idle, () {
        print('🕑 [BluetoothServerRepository] idle timeout – завершаем приём');
        completeIfNot();
      });
    }

    subscription = _transport.bytes.listen(
      (data) {
        print(
            '📨 [BluetoothServerRepository] Получен блок данных: ${data.length} байт');
        buffer.addAll(data);
        print(
            '📊 [BluetoothServerRepository] Общий размер полученных данных: ${buffer.length} байт');
        resetIdle();
      },
      onError: (error) {
        print(
            '❌ [BluetoothServerRepository] Ошибка при получении данных архива: $error');
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        print(
            '✅ [BluetoothServerRepository] Получение данных архива завершено');
        completeIfNot();
      },
    );

    // Таймаут 60 секунд для скачивания
    timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (!completer.isCompleted) {
        print(
            '⏰ [BluetoothServerRepository] Таймаут скачивания архива (60 секунд)');
        print(
            '📊 [BluetoothServerRepository] Итоговый размер полученных данных: ${buffer.length} байт');
        completeIfNot();
      }
    });

    try {
      final result = await completer.future;
      await subscription.cancel();
      timeoutTimer?.cancel();
      return result;
    } catch (e) {
      await subscription.cancel();
      timeoutTimer?.cancel();
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
