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

    try {
      const int maxAttempts = 3;
      const Duration attemptDuration = Duration(seconds: 15);

      final found = <BluetoothDeviceEntity>[];

      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        print(
            '[BluetoothRepository] Попытка сканирования ${attempt + 1}/$maxAttempts');

        try {
          _flutterBlueClassic.stopScan();
          await Future.delayed(const Duration(milliseconds: 500));
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

    // Увеличиваем таймаут для более стабильного соединения
    timeoutTimer = Timer(AppConfig.bluetoothCommandTimeout * 2, () {
      if (!finished) {
        finished = true;
        completer.completeError(TimeoutException('Таймаут подключения'));
      }
    });

    () async {
      while (attempts < maxAttempts && !finished) {
        try {
          await LogManager.bluetooth('BLUETOOTH',
              'Попытка подключения ${attempts + 1}/$maxAttempts к ${device.name}');

          connection = await _flutterBlueClassic.connect(device.address);
          if (connection == null) {
            attempts++;
            await Future.delayed(AppConfig.shortDelay);
            continue;
          }

          // Увеличиваем время ожидания стабилизации соединения
          int waitAttempts = 0;
          while (!(connection?.isConnected ?? false) && waitAttempts < 5) {
            await Future.delayed(AppConfig.veryShortDelay);
            waitAttempts++;
          }

          if (!(connection?.isConnected ?? false)) {
            attempts++;
            await Future.delayed(AppConfig.shortDelay);
            continue;
          }

          // Дополнительная проверка стабильности соединения
          await Future.delayed(const Duration(milliseconds: 200));
          if (!(connection?.isConnected ?? false)) {
            attempts++;
            await Future.delayed(AppConfig.shortDelay);
            continue;
          }

          if (!finished && connection != null) {
            finished = true;
            timeoutTimer?.cancel();
            await LogManager.bluetooth('BLUETOOTH',
                'Успешно подключились к ${device.name} после ${attempts + 1} попыток');
            completer.complete(connection);
          }
          return;
        } catch (e) {
          attempts++;
          LogManager.warning('BLUETOOTH',
              'Ошибка подключения к ${device.name}, попытка $attempts из $maxAttempts: $e');
          if (attempts < maxAttempts) {
            // Увеличиваем задержку между попытками
            await Future.delayed(AppConfig.shortDelay * 2);
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
        finalFileName += '.db';
      }

      // Извлекаем только государственный номер из имени устройства, убирая "Quantor"
      String deviceSerial = 'Unknown';
      if (device.name != null) {
        // Убираем "Quantor" из начала имени и оставляем только государственный номер
        final nameWithoutQuantor = device.name!
            .replaceFirst(RegExp(r'^Quantor\s*', caseSensitive: false), '');
        deviceSerial = nameWithoutQuantor.replaceAll(RegExp(r'[^\w]'), '');
        if (deviceSerial.isEmpty) {
          deviceSerial = 'Unknown';
        }
      }
      finalFileName =
          '${deviceSerial}_${finalFileName.replaceFirst('.db', '')}_${AppConfig.notExportedSuffix}.db';

      int receivedBytes = 0;
      int expectedFileSize = 0;
      bool isReadingFileData = false;
      bool isDownloadCompleted = false; // Флаг завершения загрузки
      bool isProcessingData =
          false; // Флаг обработки данных для предотвращения race conditions
      final responseBuffer = <int>[];
      final memoryBuffer = BytesBuilder();
      File? tempFile;
      IOSink? sink;
      bool switchedToFile = false;
      const memoryLimit = 10 * 1024 * 1024;

      int dataChunksReceived = 0;
      int lastLoggedChunkCount = 0;
      int progressUpdates = 0;
      int lastLoggedProgressCount = 0;

      Future<void> flushAndCloseSink() async {
        if (sink != null) {
          await sink!.flush();
          await sink!.close();
          sink = null;
        }
      }

      Future<void> addToBufferOrFile(List<int> data) async {
        // Проверяем, не завершена ли уже загрузка
        if (isDownloadCompleted) {
          await LogManager.bluetooth('BLUETOOTH',
              'Игнорируем данные после завершения загрузки: ${data.length} байт');
          return;
        }

        // Защита от race conditions
        if (isProcessingData) {
          await LogManager.bluetooth('BLUETOOTH',
              'Пропускаем данные во время обработки предыдущего чанка: ${data.length} байт');
          return;
        }

        isProcessingData = true;
        try {
          receivedBytes += data.length;
          dataChunksReceived++;

          // Оптимизируем логирование - реже для больших файлов
          final logInterval = expectedFileSize > 1024 * 1024 ? 100 : 50;
          if (dataChunksReceived - lastLoggedChunkCount >= logInterval) {
            await LogManager.bluetooth('BLUETOOTH',
                'Получено данных: ${dataChunksReceived - lastLoggedChunkCount} чанков, всего $receivedBytes байт');
            lastLoggedChunkCount = dataChunksReceived;
          }

          if (!switchedToFile) {
            memoryBuffer.add(data);
            // Увеличиваем лимит памяти для больших файлов
            final currentMemoryLimit = expectedFileSize > 5 * 1024 * 1024
                ? memoryLimit * 2
                : memoryLimit;
            if (memoryBuffer.length >= currentMemoryLimit) {
              await LogManager.bluetooth('BLUETOOTH',
                  'Переключаемся на сохранение в temp файл (превышен лимит памяти: ${currentMemoryLimit / 1024 / 1024} MB)');
              tempFile = File(p.join(directory.path, sanitizedFileName));
              sink = tempFile!.openWrite();
              sink!.add(memoryBuffer.takeBytes());
              switchedToFile = true;
            }
          } else {
            sink!.add(data);
          }

          if (expectedFileSize > 0) {
            final progress = receivedBytes / expectedFileSize;
            progressUpdates++;

            // Оптимизируем обновления прогресса
            final progressLogInterval =
                expectedFileSize > 1024 * 1024 ? 50 : 20;
            if (progressUpdates - lastLoggedProgressCount >=
                progressLogInterval) {
              await LogManager.bluetooth('BLUETOOTH',
                  'Прогресс загрузки: ${(progress * 100).toStringAsFixed(1)}% (${progressUpdates - lastLoggedProgressCount} обновлений)');
              lastLoggedProgressCount = progressUpdates;
            }
            onProgress?.call(progress, expectedFileSize);
          }
        } finally {
          isProcessingData = false;
        }
      }

      BluetoothConnection? connection = _connection;
      int retryCount = 0;
      const maxRetries = 2;

      while (retryCount < maxRetries && !_isCancelled) {
        try {
          // Сброс состояния для новой попытки
          receivedBytes = 0;
          expectedFileSize = 0;
          isReadingFileData = false;
          isDownloadCompleted = false;
          isProcessingData = false;
          responseBuffer.clear();
          memoryBuffer.clear();
          tempFile = null;
          sink = null;
          switchedToFile = false;
          dataChunksReceived = 0;
          lastLoggedChunkCount = 0;
          progressUpdates = 0;
          lastLoggedProgressCount = 0;

          // Отменяем предыдущую подписку если она существует
          await _downloadSubscription?.cancel();
          _downloadSubscription = null;

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
          connection.output.add(BluetoothProtocol.getArchiveCmd(fileName));

          final responseCompleter = Completer<bool>();
          int responseChunks = 0;
          int lastLoggedResponseCount = 0;

          _downloadSubscription = connection.input?.listen(
            (data) async {
              // Проверяем, не завершена ли уже загрузка
              if (isDownloadCompleted) {
                await LogManager.bluetooth('BLUETOOTH',
                    'Игнорируем чанк данных после завершения загрузки: ${data.length} байт');
                return;
              }

              responseChunks++;

              if (responseChunks - lastLoggedResponseCount >= 100) {
                await LogManager.bluetooth('BLUETOOTH',
                    'Обработано ${responseChunks - lastLoggedResponseCount} чанков ответа');
                lastLoggedResponseCount = responseChunks;
              }

              if (_isCancelled) {
                await flushAndCloseSink();
                if (!responseCompleter.isCompleted) {
                  responseCompleter.complete(false);
                }
                return;
              }

              if (!isReadingFileData) {
                responseBuffer.addAll(data);
                if (responseBuffer.length >= 8) {
                  await LogManager.bluetooth(
                      'BLUETOOTH', 'Получен заголовок файла, парсим размер');
                  final sizeBytes =
                      Uint8List.fromList(responseBuffer.sublist(0, 8));
                  expectedFileSize =
                      ByteData.view(sizeBytes.buffer).getInt64(0, Endian.big);
                  await LogManager.bluetooth('BLUETOOTH',
                      'Ожидаемый размер файла: $expectedFileSize байт (${(expectedFileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
                  final remaining = responseBuffer.sublist(8);
                  responseBuffer.clear();
                  isReadingFileData = true;
                  if (remaining.isNotEmpty) await addToBufferOrFile(remaining);
                }
              } else {
                await addToBufferOrFile(data);
              }

              // Проверяем завершение загрузки только если еще не завершена
              if (!isDownloadCompleted &&
                  expectedFileSize > 0 &&
                  receivedBytes >= expectedFileSize) {
                isDownloadCompleted = true; // Устанавливаем флаг завершения
                await LogManager.bluetooth('BLUETOOTH',
                    'Загрузка завершена: получено $receivedBytes/$expectedFileSize байт, обработано $dataChunksReceived чанков данных');
                await flushAndCloseSink();

                // Отменяем подписку на данные после завершения
                await _downloadSubscription?.cancel();
                _downloadSubscription = null;

                String finalPath;
                if (!switchedToFile) {
                  final bytes = memoryBuffer.takeBytes();
                  if (sanitizedFileName.toLowerCase().endsWith('.gz')) {
                    try {
                      if (bytes.length < 10) {
                        throw Exception(
                            'Файл слишком мал для gzip архива: ${bytes.length} байт');
                      }

                      // Проверяем gzip заголовок (магические байты: 0x1f 0x8b)
                      if (bytes[0] != 0x1f || bytes[1] != 0x8b) {
                        throw Exception(
                            'Неверный gzip заголовок: ${bytes[0].toRadixString(16)} ${bytes[1].toRadixString(16)}');
                      }

                      await LogManager.bluetooth('BLUETOOTH',
                          'Начинаем распаковку .gz файла $fileName в памяти, размер: ${bytes.length} байт');
                      final decompressedBytes = gzip.decode(bytes);
                      await LogManager.bluetooth('BLUETOOTH',
                          'Распаковка завершена, размер после распаковки: ${decompressedBytes.length} байт');

                      final rawFile =
                          File(p.join(downloadDir.path, finalFileName));
                      await rawFile.writeAsBytes(decompressedBytes);
                      finalPath = rawFile.path;

                      await LogManager.bluetooth(
                          'BLUETOOTH', 'Файл БД сохранен: $finalPath');

                      await _validateDatabaseFile(finalPath);

                      await ArchiveSyncManager.addPending(finalPath);
                    } catch (e) {
                      LogManager.error('BLUETOOTH',
                          'Ошибка распаковки .gz файла $fileName: $e');
                      finalPath =
                          p.join(directory.path, sanitizedFileName); // fallback
                      await File(finalPath).writeAsBytes(bytes);
                    }
                  } else {
                    final destPath = p.join(downloadDir.path, finalFileName);
                    await File(destPath).writeAsBytes(bytes);
                    finalPath = destPath;
                    await ArchiveSyncManager.addPending(finalPath);
                  }
                  onComplete?.call(finalPath);
                  if (!responseCompleter.isCompleted) {
                    responseCompleter.complete(true);
                  }
                } else {
                  if (sanitizedFileName.toLowerCase().endsWith('.gz')) {
                    try {
                      await LogManager.bluetooth('BLUETOOTH',
                          'Начинаем распаковку .gz файла из temp файла: ${tempFile!.path}');

                      final tempFileSize = await tempFile!.length();
                      await LogManager.bluetooth(
                          'BLUETOOTH', 'Размер temp файла: $tempFileSize байт');

                      // Валидация gzip файла перед распаковкой
                      if (tempFileSize < 10) {
                        throw Exception(
                            'Файл слишком мал для gzip архива: $tempFileSize байт');
                      }

                      // Проверяем gzip заголовок
                      final headerBytes = await tempFile!.openRead(0, 2).first;
                      if (headerBytes.length < 2 ||
                          headerBytes[0] != 0x1f ||
                          headerBytes[1] != 0x8b) {
                        throw Exception('Неверный gzip заголовок в temp файле');
                      }

                      final rawFile =
                          File(p.join(downloadDir.path, finalFileName));
                      await tempFile!
                          .openRead()
                          .transform(gzip.decoder)
                          .pipe(rawFile.openWrite());
                      finalPath = rawFile.path;

                      final decompressedSize = await rawFile.length();
                      await LogManager.bluetooth('BLUETOOTH',
                          'Распаковка завершена, размер после распаковки: $decompressedSize байт');

                      await tempFile!.delete();
                      await LogManager.bluetooth('BLUETOOTH',
                          'Temp файл удален, файл БД сохранен: $finalPath');

                      await _validateDatabaseFile(finalPath);

                      await ArchiveSyncManager.addPending(finalPath);
                    } catch (e) {
                      LogManager.error('BLUETOOTH',
                          'Ошибка распаковки .gz файла из temp: $fileName: $e');
                      finalPath = tempFile!.path; // fallback
                    }
                  } else {
                    final destPath = p.join(downloadDir.path, finalFileName);
                    bool moved = false;
                    try {
                      await tempFile!.rename(destPath);
                      moved = true;
                      await ArchiveSyncManager.addPending(destPath);
                    } catch (_) {
                      try {
                        await tempFile!.copy(destPath);
                        await tempFile!.delete();
                        moved = true;
                        await ArchiveSyncManager.addPending(destPath);
                      } catch (e) {
                        LogManager.error('BLUETOOTH',
                            'Не удалось переместить файл $fileName: $e');
                      }
                    }
                    finalPath = moved ? destPath : tempFile!.path;
                    await ArchiveSyncManager.addPending(finalPath);
                  }
                  onComplete?.call(finalPath);
                  if (!responseCompleter.isCompleted) {
                    responseCompleter.complete(true);
                  }
                }
              }
            },
            onError: (error) async {
              await LogManager.bluetooth(
                  'BLUETOOTH', 'Ошибка в потоке данных: $error');
              await flushAndCloseSink();
              if (!responseCompleter.isCompleted) {
                responseCompleter.completeError(error);
              }
            },
            onDone: () async {
              await LogManager.bluetooth('BLUETOOTH',
                  'Поток данных завершен: получено $receivedBytes байт из ожидаемых $expectedFileSize (чанков: $dataChunksReceived, ответов: $responseChunks)');
              await flushAndCloseSink();

              if (!isDownloadCompleted) {
                if (receivedBytes < expectedFileSize && !_isCancelled) {
                  LogManager.error('BLUETOOTH',
                      'Неполная передача файла $fileName: получено $receivedBytes из $expectedFileSize байт');
                  if (!responseCompleter.isCompleted) {
                    responseCompleter.complete(false);
                  }
                } else if (!responseCompleter.isCompleted) {
                  LogManager.info('BLUETOOTH',
                      'Файл $fileName успешно загружен: $receivedBytes байт');
                  responseCompleter.complete(true);
                }
              }
            },
          );

          final response = await responseCompleter.future;

          if (_isCancelled) {
            await tempFile?.delete();
            return const Right(true);
          }

          if (response) {
            // Передача успешна - вызываем onComplete
            await LogManager.bluetooth(
                'BLUETOOTH', 'Файл $fileName успешно загружен и сохранен');
            return const Right(true);
          } else {
            // Передача неуспешна - пробуем ещё раз
            retryCount++;
            LogManager.warning('BLUETOOTH',
                'Неуспешная загрузка файла $fileName, попытка $retryCount из $maxRetries (получено $receivedBytes/$expectedFileSize байт, чанков: $dataChunksReceived)');
            if (retryCount < maxRetries) {
              await Future.delayed(AppConfig.uiShortDelay);
              continue;
            }
          }
        } catch (e) {
          retryCount++;
          LogManager.error('BLUETOOTH',
              'Ошибка при загрузке файла $fileName, попытка $retryCount из $maxRetries: $e (получено $receivedBytes байт, чанков: $dataChunksReceived)');
          if (retryCount < maxRetries) {
            await Future.delayed(AppConfig.uiShortDelay);
            continue;
          }
        }
      }

      if (_isCancelled) {
        await tempFile?.delete();
        return const Right(true);
      }
      return Left(FileOperationFailure(
          message:
              'Не удалось загрузить файл после $maxRetries попыток. Файл может быть повреждён или соединение нестабильно.'));
    } catch (e) {
      return Left(FileOperationFailure(message: e.toString()));
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

      // Проверяем минимальный размер SQLite файла
      if (fileSize < 512) {
        throw Exception('Файл БД слишком мал для SQLite: $fileSize байт');
      }

      // Проверяем заголовок SQLite файла
      final bytes = await file.openRead(0, 16).first;
      if (bytes.length < 16) {
        throw Exception('Не удалось прочитать заголовок SQLite файла');
      }

      final header = String.fromCharCodes(bytes.take(16));

      if (!header.startsWith('SQLite format 3')) {
        throw Exception('Неверный заголовок SQLite файла: $header');
      }

      // Проверяем версию SQLite (байты 19-20)
      if (bytes.length >= 20) {
        final versionBytes = bytes.sublist(18, 20);
        final version = versionBytes[0] * 256 + versionBytes[1];
        await LogManager.bluetooth(
            'BLUETOOTH', 'Версия SQLite файла: $version');
      }

      // Проверяем, что файл не пустой в конце
      final lastBytes = await file.openRead(fileSize - 16, fileSize).first;
      if (lastBytes.length < 16) {
        throw Exception('Не удалось прочитать конец SQLite файла');
      }

      // Проверяем, что последние байты не все нули (признак повреждения)
      bool allZeros = true;
      for (int i = 0; i < lastBytes.length; i++) {
        if (lastBytes[i] != 0) {
          allZeros = false;
          break;
        }
      }

      if (allZeros) {
        throw Exception(
            'Конец файла БД содержит только нули - возможное повреждение');
      }

      await LogManager.bluetooth(
          'BLUETOOTH', 'Файл БД прошел расширенную проверку целостности');
    } catch (e) {
      await LogManager.bluetooth(
          'BLUETOOTH', 'Ошибка проверки целостности БД: $e', LogLevel.error);
      // Не прерываем процесс, только логируем
    }
  }
}
