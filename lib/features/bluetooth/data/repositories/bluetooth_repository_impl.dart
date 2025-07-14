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
          return Left(BluetoothFailure(
              message:
                  'Разрешения отклонены навсегда: ${permanentlyDeniedPermissions.map((p) => p.toString()).join(', ')}. Включите их в настройках приложения'));
        }

        if (deniedPermissions.isNotEmpty) {
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
        return Left(BluetoothFailure(
            message:
                'Отсутствуют критически важные разрешения: ${missingPermissions.join(', ')}. Перезапустите приложение и предоставьте все необходимые разрешения'));
      }

      return const Right(true);
    } catch (e) {
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
        print(
            '[BluetoothRepository] Устройства не найдены после $maxAttempts попыток');
      }

      return Right(found);
    } catch (e) {
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
          if (attempts < maxAttempts) {
            await Future.delayed(AppConfig.shortDelay);
          }
        }
      }
      if (!finished) {
        finished = true;
        timeoutTimer?.cancel();
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
    if (_isConnecting) {
      return Left(ConnectionFailure(message: 'Идет подключение...'));
    }

    try {
      _isConnecting = true;
      _connection = await _connectToDevice(device);

      if (_connection != null && _connection!.isConnected) {
        _isConnecting = false;
        _isConnected = true;
        return const Right(true);
      } else {
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
        // Ошибка при отправке
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
      // Ошибка при отправке
    }
  }

  @override
  Future<Either<Failure, bool>> downloadFile(
    String fileName,
    BluetoothDeviceEntity device, {
    DownloadProgressCallback? onProgress,
    DownloadCompleteCallback? onComplete,
  }) async {
    try {
      _isCancelled = false;

      final directory = await getApplicationDocumentsDirectory();

      final downloadDir = await ArchiveSyncManager.getArchivesDirectory();
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final sanitizedFileName = fileName.split(RegExp(r'[\\/]')).last;

      String deviceName = '';
      if (device.name != null) {
        deviceName = device.name!
            .replaceFirst(RegExp(r'^Quantor ', caseSensitive: false), '')
            .replaceAll(' ', '');
      }

      String baseName = sanitizedFileName.replaceAll(
          RegExp(r'\.gze?$', caseSensitive: false), '');
      if (!baseName.endsWith(AppConfig.dbExtension)) {
        baseName = '$baseName${AppConfig.dbExtension}';
      }
      final finalFileName = AppConfig.notExportedFileName(
          deviceName, baseName.replaceAll(AppConfig.dbExtension, ''));

      // Гибридная буферизация: сначала в память, при превышении лимита - в файл
      const int memoryLimit = 124 * 1024 * 1024; // 124 МБ
      BytesBuilder memoryBuffer = BytesBuilder();
      bool switchedToFile = false;
      File? tempFile;
      IOSink? sink;
      int receivedBytes = 0;
      int expectedFileSize = 0;
      bool isReadingFileData = false;
      List<int> responseBuffer = [];

      Future<void> flushAndCloseSink() async {
        if (sink != null) {
          await sink!.flush();
          await sink!.close();
          sink = null;
        }
      }

      Future<void> addToBufferOrFile(List<int> data) async {
        receivedBytes += data.length;

        if (!switchedToFile) {
          memoryBuffer.add(data);
          if (memoryBuffer.length >= memoryLimit) {
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
          onProgress?.call(progress, expectedFileSize);
        }
      }

      BluetoothConnection? connection = _connection;
      int retryCount = 0;
      const maxRetries = 2;

      while (retryCount < maxRetries && !_isCancelled) {
        try {
          if (connection == null || !(connection.isConnected)) {
            connection = await _connectToDevice(device);
            await Future.delayed(AppConfig.shortDelay);
          }

          if (connection == null || !(connection.isConnected)) {
            throw Exception('Соединение потеряно');
          }

          connection.output.add(BluetoothProtocol.getArchiveCmd(fileName));

          final responseCompleter = Completer<bool>();

          _downloadSubscription = connection.input?.listen(
            (data) async {
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
                  final sizeBytes =
                      Uint8List.fromList(responseBuffer.sublist(0, 8));
                  expectedFileSize =
                      ByteData.view(sizeBytes.buffer).getInt64(0, Endian.big);
                  final remaining = responseBuffer.sublist(8);
                  responseBuffer.clear();
                  isReadingFileData = true;
                  if (remaining.isNotEmpty) await addToBufferOrFile(remaining);
                }
              } else {
                await addToBufferOrFile(data);
              }

              if (expectedFileSize > 0 && receivedBytes >= expectedFileSize) {
                await flushAndCloseSink();
                String finalPath;
                if (!switchedToFile) {
                  final bytes = memoryBuffer.takeBytes();
                  if (sanitizedFileName.toLowerCase().endsWith('.gz')) {
                    try {
                      final rawFile =
                          File(p.join(downloadDir.path, finalFileName));
                      await rawFile.writeAsBytes(gzip.decode(bytes));
                      finalPath = rawFile.path;
                      await ArchiveSyncManager.addPending(finalPath);
                    } catch (e) {
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
                      final rawFile =
                          File(p.join(downloadDir.path, finalFileName));
                      await tempFile!
                          .openRead()
                          .transform(gzip.decoder)
                          .pipe(rawFile.openWrite());
                      finalPath = rawFile.path;
                      await tempFile!.delete();
                      await ArchiveSyncManager.addPending(finalPath);
                    } catch (e) {
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
                        // не удалось переместить
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
              await flushAndCloseSink();
              if (!responseCompleter.isCompleted) {
                responseCompleter.completeError(error);
              }
            },
            onDone: () async {
              await flushAndCloseSink();
              if (receivedBytes < expectedFileSize && !_isCancelled) {
                // Передача неполная – считаем ошибкой
                if (!responseCompleter.isCompleted) {
                  responseCompleter.complete(false); // ❌ неуспешно
                }
              } else if (!responseCompleter.isCompleted) {
                responseCompleter.complete(true); // ✅ успешно
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
            return const Right(true);
          } else {
            // Передача неуспешна - пробуем ещё раз
            retryCount++;
            if (retryCount < maxRetries) {
              await Future.delayed(AppConfig.uiShortDelay);
              continue;
            }
          }
        } catch (e) {
          retryCount++;
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
      _isCancelled = true;

      await _scanSubscription?.cancel();
      _scanSubscription = null;

      await _connectionSubscription?.cancel();
      _connectionSubscription = null;

      await _downloadSubscription?.cancel();
      _downloadSubscription = null;

      if (_connection != null) {
        _connection!.dispose();
        _connection = null;
      }

      await _transport.dispose();

      _isConnecting = false;
      _isConnected = false;
      _readyArchivePath = null;

      print('[BluetoothRepository] All resources disposed');
    } catch (e) {
      print('[BluetoothRepository] Error during dispose: $e');
    }
  }
}
