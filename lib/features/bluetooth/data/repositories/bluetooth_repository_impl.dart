import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/archive_sync_manager.dart';
import '../../../../core/utils/log_manager.dart';
import '../../domain/entities/bluetooth_device.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../protocol/bluetooth_protocol.dart';
import '../transport/bluetooth_transport.dart';

class BluetoothRepositoryImpl implements BluetoothRepository {
  final FlutterBlueClassic _flutterBlueClassic;
  final BluetoothTransport _transport;
  BluetoothConnection? _connection;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isCancelled = false;
  StreamSubscription? _downloadSubscription;
  String? _readyArchivePath;

  static final RegExp _quantorNameRegExp = AppConfig.bluetoothServerRegExp;

  BluetoothRepositoryImpl(this._transport, this._flutterBlueClassic);

  /// Проверяет необходимые разрешения и состояние Bluetooth.
  Future<Either<Failure, bool>> _checkBluetoothPermissions() async {
    try {
      // 1. Проверяем, включен ли Bluetooth
      final isBluetoothEnabledResult = await isBluetoothEnabled();
      bool bluetoothEnabled = false;
      isBluetoothEnabledResult.fold(
        (failure) => bluetoothEnabled = false,
        (enabled) => bluetoothEnabled = enabled,
      );

      if (!bluetoothEnabled) {
        await LogManager.bluetooth(
            'BLUETOOTH', 'Bluetooth отключен', LogLevel.error);
        return Left(BluetoothFailure(message: 'BLUETOOTH_DISABLED'));
      }

      final permissionsToRequest = <Permission>[];

      final androidVersion =
          Platform.isAndroid ? await _getAndroidVersion() : 0;

      if (androidVersion >= 31) {
        if (await Permission.bluetoothScan.isDenied) {
          permissionsToRequest.add(Permission.bluetoothScan);
        }
        if (await Permission.bluetoothConnect.isDenied) {
          permissionsToRequest.add(Permission.bluetoothConnect);
        }

        if (androidVersion >= 35) {
          if (await Permission.bluetoothAdvertise.isDenied) {
            permissionsToRequest.add(Permission.bluetoothAdvertise);
          }
        }
      } else if (androidVersion >= 23) {
        if (await Permission.bluetooth.isDenied) {
          permissionsToRequest.add(Permission.bluetooth);
        }

        if (await Permission.location.isDenied) {
          permissionsToRequest.add(Permission.location);
        }
      } else {
        if (await Permission.bluetooth.isDenied) {
          permissionsToRequest.add(Permission.bluetooth);
        }
      }

      if (permissionsToRequest.isNotEmpty) {
        print(
            '[BluetoothRepository] Запрашиваем разрешения: ${permissionsToRequest.map((p) => p.toString()).join(', ')}');

        final Map<Permission, PermissionStatus> results =
            await permissionsToRequest.request();

        print('[BluetoothRepository] Результаты запроса разрешений:');
        for (final entry in results.entries) {
          print('  ${entry.key}: ${entry.value}');
        }

        final deniedPermissions = <Permission>[];
        final permanentlyDeniedPermissions = <Permission>[];

        for (final permission in permissionsToRequest) {
          final status = results[permission] ?? PermissionStatus.denied;
          if (status == PermissionStatus.permanentlyDenied) {
            permanentlyDeniedPermissions.add(permission);
          } else if (status == PermissionStatus.denied) {
            deniedPermissions.add(permission);
          }
        }

        if (permanentlyDeniedPermissions.isNotEmpty) {
          await LogManager.permissions(
              'PERMISSION',
              'Разрешения отклонены навсегда: ${permanentlyDeniedPermissions.map((p) => p.toString()).join(', ')}',
              LogLevel.error);
          return Left(BluetoothFailure(
              message:
                  'Разрешения отклонены навсегда: ${permanentlyDeniedPermissions.map((p) => p.toString()).join(', ')}. Включите их в настройках приложения'));
        }

        if (deniedPermissions.isNotEmpty) {
          await LogManager.permissions(
              'PERMISSION',
              'Пользователь отклонил разрешения: ${deniedPermissions.map((p) => p.toString()).join(', ')}',
              LogLevel.error);
          return Left(BluetoothFailure(
              message:
                  'Разрешения отклонены: ${deniedPermissions.map((p) => p.toString()).join(', ')}. Поиск устройств невозможен без разрешений'));
        }
      }

      final missingPermissions = <String>[];

      if (androidVersion >= 31) {
        if (await Permission.bluetoothScan.isDenied) {
          missingPermissions.add('BLUETOOTH_SCAN');
        }
        if (await Permission.bluetoothConnect.isDenied) {
          missingPermissions.add('BLUETOOTH_CONNECT');
        }
      } else if (androidVersion >= 23) {
        if (await Permission.bluetooth.isDenied) {
          missingPermissions.add('BLUETOOTH');
        }
        if (await Permission.location.isDenied) {
          missingPermissions.add('LOCATION');
        }
      }

      if (missingPermissions.isNotEmpty) {
        await LogManager.permissions(
            'PERMISSION',
            'Отсутствуют критически важные разрешения: ${missingPermissions.join(', ')}',
            LogLevel.error);
        return Left(BluetoothFailure(
            message:
                'Отсутствуют критически важные разрешения: ${missingPermissions.join(', ')}. Перезапустите приложение и предоставьте все необходимые разрешения'));
      }

      return const Right(true);
    } catch (e) {
      await LogManager.bluetooth(
          'BLUETOOTH', 'Не удалось проверить разрешения: $e', LogLevel.error);
      return Left(BluetoothFailure(message: 'Ошибка проверки разрешений: $e'));
    }
  }

  /// Получает версию Android API
  Future<int> _getAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        print('[BluetoothRepository] Версия Android API: $sdkInt');
        return sdkInt;
      }
      return 0;
    } catch (e) {
      print('Ошибка получения версии Android: $e');
      return 35;
    }
  }

  @override
  Future<Either<Failure, List<BluetoothDeviceEntity>>> scanForDevices(
      {void Function(BluetoothDeviceEntity)? onDeviceFound}) async {
    print('[BluetoothRepository] Проверяем состояние Bluetooth...');

    // Проверяем включен ли Bluetooth
    final bluetoothEnabledResult = await isBluetoothEnabled();
    bool bluetoothEnabled = false;
    bluetoothEnabledResult.fold(
      (failure) {
        print(
            '[BluetoothRepository] Ошибка проверки Bluetooth: ${failure.message}');
        bluetoothEnabled = false;
      },
      (enabled) {
        print('[BluetoothRepository] Bluetooth включен: $enabled');
        bluetoothEnabled = enabled;
      },
    );

    if (!bluetoothEnabled) {
      await LogManager.bluetooth('BLUETOOTH',
          'Bluetooth отключен - сканирование невозможно', LogLevel.error);
      print('[BluetoothRepository] Bluetooth выключен, прерываем сканирование');
      return Left(BluetoothFailure(message: 'BLUETOOTH_DISABLED'));
    }

    print('[BluetoothRepository] Проверяем разрешения...');
    final permissionCheck = await _checkBluetoothPermissions();
    if (permissionCheck.isLeft()) {
      return permissionCheck.fold((failure) {
        print(
            '[BluetoothRepository] Разрешения не получены: ${failure.message}');
        return Left(failure);
      },
          (_) =>
              Left(BluetoothFailure(message: 'Неизвестная ошибка разрешений')));
    }

    print(
        '[BluetoothRepository] Все проверки пройдены, начинаем сканирование...');

    try {
      const int maxAttempts = 3; // Увеличиваем количество попыток
      const Duration attemptDuration =
          Duration(seconds: 15); // Увеличиваем время сканирования

      final found = <BluetoothDeviceEntity>[];

      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        print(
            '[BluetoothRepository] Попытка сканирования ${attempt + 1}/$maxAttempts');

        // Останавливаем предыдущее сканирование
        try {
          _flutterBlueClassic.stopScan();
          await Future.delayed(const Duration(
              milliseconds: 500)); // Пауза между остановкой и запуском
        } catch (e) {
          await LogManager.bluetooth(
              'BLUETOOTH',
              'Не удалось остановить предыдущее сканирование: $e',
              LogLevel.error);
          print('[BluetoothRepository] Ошибка остановки сканирования: $e');
        }

        final completer = Completer<void>();

        _scanSubscription?.cancel();
        _scanSubscription = _flutterBlueClassic.scanResults.listen(
          (d) {
            final name = d.name ?? '';

            if (!_quantorNameRegExp.hasMatch(name)) {
              return;
            }

            if (!found.any((e) => e.address == d.address)) {
              final device =
                  BluetoothDeviceEntity(address: d.address, name: d.name);
              found.add(device);
              print(
                  '[BluetoothRepository] Добавлено устройство: ${device.name}');
              onDeviceFound?.call(device);
            }
          },
          onError: (error) {
            LogManager.bluetooth('BLUETOOTH',
                'Ошибка во время сканирования: $error', LogLevel.error);
            print('[BluetoothRepository] Ошибка сканирования: $error');
          },
        );

        try {
          print('[BluetoothRepository] Запуск сканирования...');
          _flutterBlueClassic.startScan();

          await Future.any([
            completer.future,
            Future.delayed(attemptDuration),
          ]);
        } catch (e) {
          print('[BluetoothRepository] Ошибка во время сканирования: $e');
        }

        try {
          _flutterBlueClassic.stopScan();
          await _scanSubscription?.cancel();
        } catch (e) {
          print('[BluetoothRepository] Ошибка остановки сканирования: $e');
        }

        print('[BluetoothRepository] Найдено устройств: ${found.length}');

        if (found.isNotEmpty) {
          print('[BluetoothRepository] Сканирование завершено успешно');
          break;
        }

        // Пауза между попытками
        if (attempt < maxAttempts - 1) {
          print('[BluetoothRepository] Пауза перед следующей попыткой...');
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (found.isEmpty) {
        await LogManager.bluetooth(
            'BLUETOOTH',
            'Не найдено ни одного устройства Quantor после $maxAttempts попыток сканирования',
            LogLevel.warning);
        print(
            '[BluetoothRepository] Устройства не найдены после $maxAttempts попыток');
      }

      return Right(found);
    } catch (e) {
      await LogManager.bluetooth(
          'BLUETOOTH', 'Не удалось выполнить сканирование: $e', LogLevel.error);
      print('[BluetoothRepository] Критическая ошибка сканирования: $e');
      return Left(BluetoothFailure(message: e.toString()));
    }
  }

  Future<BluetoothConnection> _connectToDevice(
      BluetoothDeviceEntity device) async {
    BluetoothConnection? connection;
    int attempts = 0;
    const maxAttempts = 10;
    final completer = Completer<BluetoothConnection?>();
    Timer? timeoutTimer;
    bool finished = false;
    timeoutTimer = Timer(AppConfig.bluetoothCommandTimeout, () {
      if (!finished) {
        finished = true;
        completer.completeError(TimeoutException('Таймаут подключения'));
      }
    });
    () async {
      while (attempts < maxAttempts && !finished) {
        try {
          connection = await _flutterBlueClassic.connect(device.address);
          if (connection == null) {
            attempts++;
            await Future.delayed(AppConfig.shortDelay);
            continue;
          }
          int waitAttempts = 0;
          while (!(connection?.isConnected ?? false) && waitAttempts < 3) {
            await Future.delayed(AppConfig.veryShortDelay);
            waitAttempts++;
          }
          if (!(connection?.isConnected ?? false)) {
            attempts++;
            await Future.delayed(AppConfig.shortDelay);
            continue;
          }
          if (!finished && connection != null) {
            finished = true;
            timeoutTimer?.cancel();
            completer.complete(connection);
          }
          return;
        } catch (e) {
          attempts++;
          LogManager.warning('BLUETOOTH',
              'Ошибка подключения к ${device.name}, попытка $attempts из $maxAttempts: $e');
          if (attempts < maxAttempts) {
            await Future.delayed(AppConfig.shortDelay);
          }
        }
      }
      if (!finished) {
        finished = true;
        timeoutTimer?.cancel();
        LogManager.error('BLUETOOTH',
            'Не удалось подключиться к ${device.name} после $maxAttempts попыток');
        completer.completeError(
            Exception('Не удалось подключиться после $maxAttempts попыток'));
      }
    }();
    final result = await completer.future;
    if (result == null) throw Exception('Соединение не установлено');
    return result;
  }

  @override
  Future<Either<Failure, bool>> connectToDevice(
      BluetoothDeviceEntity device) async {
    await LogManager.bluetooth('BLUETOOTH',
        'Попытка подключения к устройству: ${device.name} [${device.address}]');

    if (_isConnecting) {
      await LogManager.bluetooth(
          'BLUETOOTH', 'Подключение уже выполняется', LogLevel.warning);
      return Left(ConnectionFailure(message: 'Идет подключение...'));
    }

    try {
      _isConnecting = true;
      _connection = await _connectToDevice(device);

      if (_connection != null && _connection!.isConnected) {
        await LogManager.bluetooth(
            'BLUETOOTH', 'Успешно подключились к устройству: ${device.name}');
        _isConnecting = false;
        _isConnected = true;
        return const Right(true);
      } else {
        await LogManager.bluetooth(
            'BLUETOOTH',
            'Не удалось подключиться к устройству: ${device.name}',
            LogLevel.error);
        _isConnecting = false;
        _isConnected = false;
        return Left(
            ConnectionFailure(message: 'Не удалось установить соединение'));
      }
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      return Left(ConnectionFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> disconnectFromDevice(
      BluetoothDeviceEntity device) async {
    try {
      if (_connection != null) {
        _connection!.dispose();
        _connection = null;
      }
      _isConnected = false;
      return const Right(true);
    } catch (e) {
      return Left(ConnectionFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getReadyArchive() async {
    if (_readyArchivePath != null) {
      return Right([_readyArchivePath!]);
    }
    return Left(ConnectionFailure(message: 'Путь к архиву не готов'));
  }

  void _sendWriteUTF(String message) {
    if (_connection != null && _connection!.isConnected) {
      try {
        final encoded = utf8.encode(message);
        final length = encoded.length;

        final bytes = Uint8List(2 + length);
        bytes[0] = (length >> 8) & 0xFF;
        bytes[1] = length & 0xFF;
        bytes.setAll(2, encoded);

        _connection!.output.add(bytes);
      } catch (e) {
        LogManager.error('BLUETOOTH', 'Ошибка при отправке сообщения: $e');
      }
    } else {
      // Нет подключения
    }
  }

  void _sendWriteUTFWithConnection(
      BluetoothConnection connection, String message) {
    if (!connection.isConnected) {
      return;
    }

    try {
      final encoded = utf8.encode(message);
      final length = encoded.length;
      final bytes = Uint8List(2 + length);
      bytes[0] = (length >> 8) & 0xFF;
      bytes[1] = length & 0xFF;
      bytes.setAll(2, encoded);

      if (connection.isConnected) {
        connection.output.add(bytes);
      }
    } catch (e) {
      LogManager.error('BLUETOOTH', 'Ошибка при отправке UTF сообщения: $e');
    }
  }

  @override
  Future<Either<Failure, bool>> downloadFile(
    String fileName,
    BluetoothDeviceEntity device, {
    DownloadProgressCallback? onProgress,
    DownloadCompleteCallback? onComplete,
  }) async {
    await LogManager.bluetooth('BLUETOOTH',
        'Начинаем загрузку файла: $fileName с устройства ${device.name}');

    _isCancelled = false;

    try {
      final directory = await getTemporaryDirectory();
      final downloadDir = await ArchiveSyncManager.getArchivesDirectory();

      final sanitizedFileName = fileName.replaceAll('/', '_');
      String finalFileName = sanitizedFileName;
      if (finalFileName.toLowerCase().endsWith('.gz')) {
        finalFileName = finalFileName.substring(0, finalFileName.length - 3);
      }

      if (!finalFileName.toLowerCase().endsWith('.db')) {
        finalFileName = '${finalFileName}_NEED_EXPORT.db';
      }

      final deviceName = device.name?.replaceAll(' ', '') ?? 'Unknown';
      final finalPath =
          p.join(downloadDir.path, '${deviceName}${finalFileName}');

      await LogManager.bluetooth(
          'BLUETOOTH', 'Файл будет сохранен как: $finalPath');

      BluetoothConnection? connection = _connection;
      int retryCount = 0;
      const maxRetries = 2;

      while (retryCount < maxRetries && !_isCancelled) {
        try {
          if (connection == null || !(connection.isConnected)) {
            await LogManager.bluetooth('BLUETOOTH',
                'Переподключаемся к устройству для загрузки файла (попытка ${retryCount + 1})');
            connection = await _connectToDevice(device);
            await Future.delayed(AppConfig.shortDelay);
          }

          if (connection == null || !(connection.isConnected)) {
            LogManager.error('BLUETOOTH',
                'Соединение потеряно при загрузке файла $fileName');
            throw Exception('Соединение потеряно');
          }

          await LogManager.bluetooth(
              'BLUETOOTH', 'Отправляем команду получения архива: $fileName');

          // Отправляем команду получения файла
          await LogManager.bluetooth(
              'BLUETOOTH', 'Отправляем команду получения архива: $fileName');
          connection.output.add(BluetoothProtocol.getArchiveCmd(fileName));

          // Ожидаем ответ от устройства
          await LogManager.bluetooth(
              'BLUETOOTH', 'Ожидаем ответ от устройства...');
          final response = await connection.input!.first;

          // Декодируем ответ вручную (так как _decode приватный)
          String responseStr = '';
          if (response.length >= 2) {
            final len = (response[0] << 8) | response[1];
            if (response.length >= 2 + len) {
              responseStr = utf8.decode(response.sublist(2, 2 + len));
            }
          }

          await LogManager.bluetooth(
              'BLUETOOTH', 'Получен ответ от устройства: $responseStr');

          // Проверяем различные форматы ответа
          int expectedFileSize = 0;

          if (responseStr.startsWith('FILE_SIZE:')) {
            final sizeStr = responseStr.substring(10).trim();
            expectedFileSize = int.tryParse(sizeStr) ?? 0;
          } else if (responseStr.startsWith('SIZE:')) {
            final sizeStr = responseStr.substring(5).trim();
            expectedFileSize = int.tryParse(sizeStr) ?? 0;
          } else if (responseStr == 'OK' || responseStr == 'READY') {
            // Устройство готово отправлять файл, но размер неизвестен
            await LogManager.bluetooth('BLUETOOTH',
                'Устройство готово к отправке файла, размер будет определен динамически');
            expectedFileSize = -1; // Флаг для динамического определения
          } else {
            await LogManager.bluetooth('BLUETOOTH',
                'Неизвестный формат ответа, предполагаем что файл начинается сразу');
            expectedFileSize = -1; // Флаг для динамического определения
          }

          if (expectedFileSize > 0) {
            await LogManager.bluetooth('BLUETOOTH',
                'Ожидаемый размер файла: $expectedFileSize байт (${(expectedFileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
          }

          // Накапливаем данные в памяти (для небольших файлов) или записываем на диск (для больших)
          const int memoryLimit = 10 * 1024 * 1024; // 10 MB лимит для памяти
          List<int>? memoryBuffer;
          File? tempFile;
          IOSink? fileSink;
          bool useFileStorage =
              expectedFileSize > memoryLimit || expectedFileSize == -1;

          int receivedBytes = 0;
          int dataChunksReceived = 0;
          int progressUpdateCounter = 0;

          if (useFileStorage) {
            await LogManager.bluetooth('BLUETOOTH',
                'Файл большой (${(expectedFileSize / 1024 / 1024).toStringAsFixed(1)} MB), используем потоковую запись на диск');
            tempFile = File(p.join(directory.path, 'temp_$sanitizedFileName'));
            fileSink = tempFile!.openWrite();
          } else {
            await LogManager.bluetooth('BLUETOOTH',
                'Файл небольшой (${(expectedFileSize / 1024 / 1024).toStringAsFixed(1)} MB), используем память');
            memoryBuffer = [];
          }

          // Для динамического размера добавляем таймаут
          final downloadTimeout = expectedFileSize == -1
              ? Duration(seconds: 30) // 30 секунд для неизвестного размера
              : Duration(seconds: 60); // 60 секунд для известного размера

          final startTime = DateTime.now();

          await for (final chunk
              in connection.input!.timeout(downloadTimeout)) {
            if (_isCancelled) {
              await LogManager.bluetooth(
                  'BLUETOOTH', 'Загрузка отменена пользователем');
              await fileSink?.close();
              await tempFile?.delete();
              return const Left(
                  FileOperationFailure(message: 'Операция отменена'));
            }

            if (useFileStorage) {
              fileSink!.add(chunk);
            } else {
              memoryBuffer!.addAll(chunk);
            }

            receivedBytes += chunk.length;
            dataChunksReceived++;

/*            progressUpdateCounter++;
            if (progressUpdateCounter >= 20) {
              final progress =
                  (receivedBytes / expectedFileSize * 100).toStringAsFixed(1);
              await LogManager.bluetooth('BLUETOOTH',
                  'Прогресс загрузки: ${progress}% (20 обновлений)');

              if (onProgress != null) {
                final progress = receivedBytes / expectedFileSize;
                onProgress(progress, expectedFileSize);
              }
              progressUpdateCounter = 0;
            }*/

            // Проверяем завершение загрузки
            if (expectedFileSize > 0 && receivedBytes >= expectedFileSize) {
              await LogManager.bluetooth('BLUETOOTH',
                  'Загрузка завершена: получено $receivedBytes/$expectedFileSize байт, обработано $dataChunksReceived чанков данных');
              break;
            } else if (expectedFileSize == -1) {
              // Для динамического размера - проверяем таймаут или специальные маркеры
              if (dataChunksReceived % 100 == 0) {
                await LogManager.bluetooth('BLUETOOTH',
                    'Получено данных: $receivedBytes байт, чанков: $dataChunksReceived');
              }

              // Проверяем таймаут для динамического размера
              final elapsed = DateTime.now().difference(startTime);
              if (elapsed.inSeconds > 25) {
                // 25 секунд из 30
                await LogManager.bluetooth('BLUETOOTH',
                    'Загрузка завершена по таймауту: получено $receivedBytes байт за ${elapsed.inSeconds} секунд');
                break;
              }
            }
          }

          if (useFileStorage) {
            await fileSink!.close();
            await LogManager.bluetooth(
                'BLUETOOTH', 'Временный файл сохранен: ${tempFile!.path}');
          }

          // Проверяем полноту загрузки
          if (expectedFileSize > 0 && receivedBytes < expectedFileSize) {
            LogManager.error('BLUETOOTH',
                'Неполная передача файла $fileName: получено $receivedBytes из $expectedFileSize байт');
            await tempFile?.delete();
            retryCount++;
            if (retryCount < maxRetries) {
              await Future.delayed(AppConfig.uiShortDelay);
              continue;
            } else {
              throw Exception(
                  'Не удалось загрузить файл полностью после $maxRetries попыток');
            }
          } else if (expectedFileSize == -1 && receivedBytes == 0) {
            LogManager.error('BLUETOOTH', 'Не получено данных от устройства');
            await tempFile?.delete();
            retryCount++;
            if (retryCount < maxRetries) {
              await Future.delayed(AppConfig.uiShortDelay);
              continue;
            } else {
              throw Exception('Не получено данных после $maxRetries попыток');
            }
          }

          // Обрабатываем .gz файлы
          if (sanitizedFileName.toLowerCase().endsWith('.gz')) {
            try {
              if (useFileStorage) {
                await LogManager.bluetooth('BLUETOOTH',
                    'Начинаем распаковку .gz файла с диска: ${tempFile!.path}');

                // Потоковая распаковка для больших файлов
                final rawFile = File(finalPath);
                await tempFile!
                    .openRead()
                    .transform(gzip.decoder)
                    .pipe(rawFile.openWrite());

                final decompressedSize = await rawFile.length();
                await LogManager.bluetooth('BLUETOOTH',
                    'Распаковка завершена, размер после распаковки: $decompressedSize байт');
              } else {
                await LogManager.bluetooth('BLUETOOTH',
                    'Начинаем распаковку .gz файла из памяти, размер: ${memoryBuffer!.length} байт');

                final decompressedBytes = gzip.decode(memoryBuffer!);
                await LogManager.bluetooth('BLUETOOTH',
                    'Распаковка завершена, размер после распаковки: ${decompressedBytes.length} байт');

                final rawFile = File(finalPath);
                await rawFile.writeAsBytes(decompressedBytes);
              }

              await LogManager.bluetooth(
                  'BLUETOOTH', 'Файл БД сохранен: $finalPath');

              // Проверяем целостность БД
              await LogManager.bluetooth(
                  'BLUETOOTH', 'Проверяем целостность БД файла: $finalPath');
              await _validateDatabaseFile(finalPath);
            } catch (e) {
              LogManager.error('BLUETOOTH', 'Ошибка распаковки .gz файла: $e');
              retryCount++;
              if (retryCount < maxRetries) {
                await Future.delayed(AppConfig.uiShortDelay);
                continue;
              } else {
                throw Exception(
                    'Не удалось распаковать файл после $maxRetries попыток: $e');
              }
            }
          } else {
            // Копируем файл
            if (useFileStorage) {
              final rawFile = File(finalPath);
              await tempFile!.copy(rawFile.path);
              await LogManager.bluetooth(
                  'BLUETOOTH', 'Файл скопирован: $finalPath');
            } else {
              final rawFile = File(finalPath);
              await rawFile.writeAsBytes(memoryBuffer!);
              await LogManager.bluetooth(
                  'BLUETOOTH', 'Файл сохранен: $finalPath');
            }
          }

          // Удаляем временный файл
          if (useFileStorage && await tempFile!.exists()) {
            await tempFile!.delete();
            await LogManager.bluetooth('BLUETOOTH', 'Временный файл удален');
          }

          await LogManager.bluetooth(
              'BLUETOOTH', 'Файл $fileName успешно загружен и сохранен');

          if (onComplete != null) {
            onComplete(finalPath);
          }

          return const Right(true);
        } catch (e) {
          retryCount++;
          LogManager.error('BLUETOOTH',
              'Ошибка при загрузке файла $fileName (попытка $retryCount): $e');

          if (retryCount < maxRetries) {
            await Future.delayed(AppConfig.uiShortDelay);
            continue;
          } else {
            return Left(FileOperationFailure(
                message:
                    'Не удалось загрузить файл после $maxRetries попыток: $e'));
          }
        }
      }

      return const Left(FileOperationFailure(
          message: 'Превышено количество попыток загрузки'));
    } catch (e) {
      LogManager.error(
          'BLUETOOTH', 'Критическая ошибка при загрузке файла: $e');
      return Left(FileOperationFailure(message: 'Ошибка загрузки файла: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> cancelDownload() async {
    try {
      _isCancelled = true;
      await _downloadSubscription?.cancel();
      _downloadSubscription = null;
      return const Right(true);
    } catch (e) {
      return Left(FileOperationFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isBluetoothEnabled() async {
    try {
      final isEnabled = await _flutterBlueClassic.isEnabled;
      return Right(isEnabled);
    } catch (e) {
      return Left(BluetoothFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> enableBluetooth() async {
    try {
      _flutterBlueClassic.turnOn();

      // Ждем некоторое время для включения Bluetooth и проверяем статус
      await Future.delayed(AppConfig.serverConnectionRetryDelay);

      final isEnabledResult = await isBluetoothEnabled();
      return isEnabledResult.fold(
        (failure) => Left(BluetoothFailure(
            message:
                'Не удалось проверить статус Bluetooth: ${failure.message}')),
        (isEnabled) {
          if (isEnabled) {
            return const Right(true);
          } else {
            return Left(BluetoothFailure(
                message: 'Пользователь отклонил включение Bluetooth'));
          }
        },
      );
    } catch (e) {
      return Left(BluetoothFailure(message: e.toString()));
    }
  }

  Future<void> _listenToConnection(BluetoothConnection connection) async {
    connection.input?.listen(
      (data) {
        if (data.length >= 2) {
          final response = utf8.decode(data);
        }
      },
      onDone: () {
        _isConnected = false;
        _connection = null;
      },
      onError: (error) {
        _isConnected = false;
        _connection = null;
      },
    );
  }

  /// Запрашивает обновление архива.
  /// Возвращает [Stream] с состояниями: 'ARCHIVE_UPDATING', 'ARCHIVE_READY'.
  @override
  Stream<String> requestArchiveUpdate() {
    final controller = StreamController<String>();
    if (_connection == null || !_connection!.isConnected) {
      controller.add('NOT_CONNECTED');
      controller.close();
      return controller.stream;
    }
    final completer = Completer<void>();
    final subscription = _connection!.input?.listen((Uint8List data) {
      if (BluetoothProtocol.isArchiveUpdating(data)) {
        controller.add('ARCHIVE_UPDATING');
      } else if (BluetoothProtocol.isArchiveReady(data)) {
        final path = BluetoothProtocol.extractArchivePath(data);
        _readyArchivePath = path;
        controller.add(path != null ? 'ARCHIVE_READY:$path' : 'ARCHIVE_READY');
        completer.complete();
      }
    }, onError: (e) {
      controller.addError(e);
      completer.completeError(e);
    }, onDone: () {
      if (!completer.isCompleted) completer.complete();
    });
    _connection!.output.add(BluetoothProtocol.updateArchiveCmd());
    completer.future.whenComplete(() async {
      await subscription?.cancel();
      await controller.close();
    });
    return controller.stream;
  }

  @override
  void cancelScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _flutterBlueClassic.stopScan();
  }

  Future<void> dispose() async {
    try {
      print('[BluetoothRepository] Disposing repository...');
      await cancelDownload();

      await _downloadSubscription?.cancel();
      _downloadSubscription = null;

      await _scanSubscription?.cancel();
      _scanSubscription = null;

      if (_connection != null) {
        _connection!.dispose();
        _connection = null;
      }

      _isConnected = false;
      _isConnecting = false;
      _isCancelled = false;
      print('[BluetoothRepository] Repository disposed successfully');
    } catch (e) {
      print('[BluetoothRepository] Error during disposal: $e');
    }
  }

  /// Проверяет целостность файла базы данных SQLite
  Future<void> _validateDatabaseFile(String filePath) async {
    try {
      await LogManager.bluetooth(
          'BLUETOOTH', 'Проверяем целостность БД файла: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Файл БД не существует: $filePath');
      }

      final fileSize = await file.length();
      await LogManager.bluetooth(
          'BLUETOOTH', 'Размер файла БД: $fileSize байт');

      // Проверяем заголовок SQLite файла
      final bytes = await file.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes.take(16));

      if (!header.startsWith('SQLite format 3')) {
        throw Exception('Неверный заголовок SQLite файла: $header');
      }

      await LogManager.bluetooth(
          'BLUETOOTH', 'Файл БД прошел базовую проверку целостности');
    } catch (e) {
      await LogManager.bluetooth(
          'BLUETOOTH', 'Ошибка проверки целостности БД: $e', LogLevel.error);
      // Не прерываем процесс, только логируем
    }
  }
}
