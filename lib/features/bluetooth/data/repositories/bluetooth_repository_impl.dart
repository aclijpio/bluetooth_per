import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/failures.dart';
import '../../domain/entities/bluetooth_device.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../protocol/bluetooth_protocol.dart';
import '../transport/bluetooth_transport.dart';
import '../../../../core/utils/archive_sync_manager.dart';
import 'package:bluetooth_per/core/utils/constants.dart';

class BluetoothRepositoryImpl implements BluetoothRepository {
  final FlutterBlueClassic _flutterBlueClassic;
  final BluetoothTransport _transport;
  BluetoothConnection? _connection;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  List<String> _fileList = [];
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isCancelled = false;
  StreamSubscription? _downloadSubscription;
  String? _readyArchivePath;

  /// Паттерн допустимого имени устройства «Quantor A000AA0000».
  /// Пример: Quantor A123BC, Quantor A123BC1234.
  static final RegExp _quantorNameRegExp =
      RegExp(r'^Quantor [A-Z]\d{3}[A-Z]{2}\d{0,4}$', caseSensitive: false);

  BluetoothRepositoryImpl(this._transport, this._flutterBlueClassic);

  @override
  Future<Either<Failure, List<BluetoothDeviceEntity>>> scanForDevices() async {
    try {
      const int maxAttempts = AppConstants.bluetoothScanMaxAttempts;
      const Duration attemptDuration =
          AppConstants.bluetoothScanAttemptDuration;

      final found = <BluetoothDeviceEntity>[];

      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        _flutterBlueClassic.stopScan(); // на всякий

        final completer = Completer<void>();

        _scanSubscription?.cancel();
        _scanSubscription = _flutterBlueClassic.scanResults.listen((d) {
          final name = d.name ?? '';
          if (!_quantorNameRegExp.hasMatch(name)) return;

          // сохраняем новое устройство
          if (!found.any((e) => e.address == d.address)) {
            found.add(BluetoothDeviceEntity(address: d.address, name: d.name));
          }

          // как только нашли хотя бы одно, завершаем попытку досрочно
/*
          if (!completer.isCompleted) completer.complete();
*/
        });

        _flutterBlueClassic.startScan();

        // ждём либо находку, либо таймаут 5 cек
        await Future.any([
          completer.future,
          Future.delayed(attemptDuration),
        ]);

        _flutterBlueClassic.stopScan();
        await _scanSubscription?.cancel();

        if (found.isNotEmpty) break; // успех

        // небольшая пауза перед следующей попыткой
        await Future.delayed(const Duration(seconds: 1));
      }

      return Right(found);
    } catch (e) {
      return Left(BluetoothFailure(message: e.toString()));
    }
  }

  Future<BluetoothConnection> _connectToDevice(
      BluetoothDeviceEntity device) async {
    print('Connecting to device: ${device.address}');
    BluetoothConnection? connection;
    int attempts = 0;
    const maxAttempts = AppConstants.bluetoothConnectMaxAttempts;
    // Несколько попыток подключения
    while (attempts < maxAttempts) {
      try {
        connection = await _flutterBlueClassic.connect(device.address);

        if (connection == null) {
          attempts++;
          await Future.delayed(AppConstants.bluetoothConnectRetryDelay);
          continue;
        }

        int waitAttempts = 0;
        while (!connection.isConnected && waitAttempts < 3) {
          await Future.delayed(AppConstants.bluetoothConnectWaitDelay);
          waitAttempts++;
        }

        if (!connection.isConnected) {
          attempts++;
          await Future.delayed(AppConstants.bluetoothConnectRetryDelay);
          continue;
        }

        return connection;
      } catch (e) {
        attempts++;
        if (attempts < maxAttempts) {
          await Future.delayed(AppConstants.bluetoothConnectRetryDelay);
        }
      }
    }

    throw Exception(
        'Failed to establish connection after $maxAttempts attempts');
  }

  @override
  Future<Either<Failure, bool>> connectToDevice(
      BluetoothDeviceEntity device) async {
    if (_isConnecting) {
      print('Already connecting to a device');
      return Left(ConnectionFailure(message: 'Connection in progress'));
    }

    try {
      _isConnecting = true;
      _connection = await _connectToDevice(device);

      if (_connection != null && _connection!.isConnected) {
        print('Connection established successfully');
        _isConnecting = false;
        _isConnected = true;
        return const Right(true);
      } else {
        print('Connection failed or not established');
        _isConnecting = false;
        _isConnected = false;
        return Left(
            ConnectionFailure(message: 'Failed to establish connection'));
      }
    } catch (e) {
      print('Error connecting to device: $e');
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
  Future<Either<Failure, List<String>>> getFileList() async {
    if (_readyArchivePath != null) {
      return Right([_readyArchivePath!]);
    }
    return Left(ConnectionFailure(message: 'Archive path not ready'));
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
        print('Error sending message via writeUTF: $e');
      }
    } else {
      print('Cannot send message: not connected');
    }
  }

  void _sendWriteUTFWithConnection(
      BluetoothConnection connection, String message) {
    if (!connection.isConnected) {
      print('Cannot send message: connection is not established');
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
      } else {
        print('Connection lost before sending message');
      }
    } catch (e) {
      print('Error sending message via writeUTF: $e');
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
      print('Starting file download for: $fileName');

      final directory = await getApplicationDocumentsDirectory();

      // ----------------- Выбираем целевую директорию -----------------
      // Пытаемся сохранить в общий каталог Download/quan во внешнем хранилище.
      Directory downloadDir;
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          // Для пути вида "/storage/emulated/0/Android/data/..." берём часть до
          // "Android" и добавляем "Download/quan".
          final rootPath = extDir.path.split('Android').first;
          downloadDir = Directory(p.join(rootPath, 'Download', 'quan'));
        } else {
          // Fallback на стандартный путь
          downloadDir = Directory('/storage/emulated/0/Download/quan');
        }
      } catch (_) {
        downloadDir = Directory('/storage/emulated/0/Download/quan');
      }

      if (!(await downloadDir.exists())) {
        await downloadDir.create(recursive: true);
      }

      // Допустим в пути могут быть разделители "/" или "\\".
      final sanitizedFileName = fileName.split(RegExp(r'[\\/]')).last;

      // Получаем имя устройства без "Quantor " и пробелов
      String deviceName = '';
      if (device.name != null) {
        deviceName = device.name!
            .replaceFirst(RegExp(r'^Quantor ', caseSensitive: false), '')
            .replaceAll(' ', '');
      }

      // Формируем итоговое имя файла: <deviceName>_<fileName>.db.pending (без .gz)
      String baseName = sanitizedFileName.replaceAll(
          RegExp(r'\.gze?$', caseSensitive: false), '');
      if (!baseName.endsWith('.db')) baseName = '$baseName.db';
      final finalFileName = deviceName.isNotEmpty
          ? '${deviceName}_$baseName.pending'
          : '$baseName.pending';

      // Сначала сохраняем во временный файл внутри internal storage, затем
      // перенесём. Это гарантирует, что у нас есть права на запись.
      final tempFile = File(p.join(directory.path, sanitizedFileName));
      await tempFile.parent.create(recursive: true);

      print('Will save temporary file to: ${tempFile.path}');

      bool isDbFile = fileName.toLowerCase().endsWith('.db') ||
          fileName.toLowerCase().endsWith('.db.gz');

      final sink = tempFile.openWrite();
      bool sinkClosed = false;
      print('File sink opened');

      // Reuse уже открытое соединение, если оно есть
      BluetoothConnection? connection = _connection;
      int retryCount = 0;
      const maxRetries = 3;
      int receivedBytes = 0;
      int expectedFileSize = 0;
      bool isReadingFileData = false;
      List<int> responseBuffer = [];
      List<int> allReceivedData = [];

      while (retryCount < maxRetries && !_isCancelled) {
        try {
          if (connection == null || !(connection.isConnected)) {
            print(
                'Connecting to device: ${device.address} (attempt ${retryCount + 1})');
            connection = await _connectToDevice(device);
            await Future.delayed(const Duration(milliseconds: 500));
          }

          if (connection == null || !(connection.isConnected)) {
            throw Exception('Connection lost');
          }

          print('Sending GET_ARCHIVE request');
          connection.output.add(BluetoothProtocol.getArchiveCmd(fileName));

          final responseCompleter = Completer<bool>();

          _downloadSubscription = connection.input?.listen(
            (data) async {
              if (_isCancelled) {
                print('Download cancelled');
                if (!sinkClosed) {
                  await sink.flush();
                  await sink.close();
                  sinkClosed = true;
                }
                responseCompleter.complete(false);
                return;
              }

              print('Received data chunk: ${data.length} bytes');

              if (!isReadingFileData) {
                // Собираем первые 8 байт – размер файла
                responseBuffer.addAll(data);

                if (responseBuffer.length >= 8) {
                  final sizeBytes =
                      Uint8List.fromList(responseBuffer.sublist(0, 8));
                  expectedFileSize =
                      ByteData.view(sizeBytes.buffer).getInt64(0, Endian.big);
                  print('File size received: $expectedFileSize');

                  final remaining = responseBuffer.sublist(8);
                  responseBuffer.clear();
                  isReadingFileData = true;

                  if (remaining.isNotEmpty && !sinkClosed) {
                    try {
                      sink.add(remaining);
                    } catch (_) {}
                    receivedBytes += remaining.length;
                    allReceivedData.addAll(remaining);
                  }

                  if (expectedFileSize > 0) {
                    final progress = receivedBytes / expectedFileSize;
                    onProgress?.call(progress, expectedFileSize);
                  }
                }
              } else {
                if (!sinkClosed) {
                  try {
                    sink.add(data);
                  } catch (_) {}
                }
                receivedBytes += data.length;
                allReceivedData.addAll(data);

                if (expectedFileSize > 0) {
                  final progress = receivedBytes / expectedFileSize;
                  onProgress?.call(progress, expectedFileSize);
                  if (receivedBytes >= expectedFileSize) {
                    print('File download completed successfully');

                    print('Всего bytes received: ${allReceivedData.length}');
                    print('Размер файла: $expectedFileSize');
                    print(
                        'Первые 20 numbers: ${allReceivedData.take(20).map((b) => b & 0xFF).join(', ')}');
                    print(
                        'Последнии 20 numbers: ${allReceivedData.reversed.take(20).toList().reversed.map((b) => b & 0xFF).join(', ')}');

                    if (!sinkClosed) {
                      await sink.flush();
                      await sink.close();
                      sinkClosed = true;
                    }

                    // -------- Сохраняем в <documents>/download/quan --------
                    String finalPath;

                    if (sanitizedFileName.toLowerCase().endsWith('.gz')) {
                      try {
                        final rawFile =
                            File(p.join(downloadDir.path, finalFileName));
                        await tempFile
                            .openRead()
                            .transform(gzip.decoder)
                            .pipe(rawFile.openWrite());
                        finalPath = rawFile.path;
                        await tempFile.delete();
                        await ArchiveSyncManager.addPending(finalPath);
                      } catch (e) {
                        print('Error while decompressing: $e');
                        finalPath = tempFile.path; // fallback
                      }
                    } else {
                      // Просто переносим файл в download/quan
                      final destPath = p.join(downloadDir.path, finalFileName);
                      bool moved = false;
                      try {
                        await tempFile.rename(destPath);
                        moved = true;
                        await ArchiveSyncManager.addPending(destPath);
                      } catch (_) {
                        try {
                          await tempFile.copy(destPath);
                          await tempFile.delete();
                          moved = true;
                          await ArchiveSyncManager.addPending(destPath);
                        } catch (e) {
                          print('Cannot move file to downloads: $e');
                        }
                      }
                      finalPath = moved ? destPath : tempFile.path;
                      await ArchiveSyncManager.addPending(finalPath);
                    }

                    onComplete?.call(finalPath);

                    if (!responseCompleter.isCompleted) {
                      responseCompleter.complete(true);
                    }
                  }
                }
              }
            },
            onError: (error) {
              print('Error during file download: $error');
              if (!responseCompleter.isCompleted) {
                responseCompleter.completeError(error);
              }
            },
            onDone: () async {
              print(
                  'Connection closed, received $receivedBytes of $expectedFileSize bytes');
              if (receivedBytes < expectedFileSize && !_isCancelled) {
                print(
                    'Connection closed before download completed, will retry');
                if (!responseCompleter.isCompleted) {
                  responseCompleter.complete(false);
                }
              } else {
                print('\nDownload Summary:');
                print('Total bytes received: ${allReceivedData.length}');
                print('Expected file size: $expectedFileSize');
                print(
                    'First 20 numbers: ${allReceivedData.take(20).map((b) => b & 0xFF).join(', ')}');
                print(
                    'Last 20 numbers: ${allReceivedData.reversed.take(20).toList().reversed.map((b) => b & 0xFF).join(', ')}');

                if (!sinkClosed) {
                  await sink.flush();
                  await sink.close();
                  sinkClosed = true;
                }

                // -------- Перемещаем/распаковываем в download/quan (onDone) --------
                String finalPath;

                if (sanitizedFileName.toLowerCase().endsWith('.gz')) {
                  try {
                    final rawFile =
                        File(p.join(downloadDir.path, finalFileName));
                    await tempFile
                        .openRead()
                        .transform(gzip.decoder)
                        .pipe(rawFile.openWrite());
                    finalPath = rawFile.path;
                    await tempFile.delete();
                    await ArchiveSyncManager.addPending(finalPath);
                  } catch (e) {
                    print('Error while decompressing (onDone): $e');
                    finalPath = tempFile.path;
                  }
                } else {
                  final destPath = p.join(downloadDir.path, finalFileName);
                  bool moved = false;
                  try {
                    await tempFile.rename(destPath);
                    moved = true;
                    await ArchiveSyncManager.addPending(destPath);
                  } catch (_) {
                    try {
                      await tempFile.copy(destPath);
                      await tempFile.delete();
                      moved = true;
                      await ArchiveSyncManager.addPending(destPath);
                    } catch (e) {
                      print('Cannot move file to downloads (onDone): $e');
                    }
                  }
                  finalPath = moved ? destPath : tempFile.path;
                  await ArchiveSyncManager.addPending(finalPath);
                }

                onComplete?.call(finalPath);

                if (!responseCompleter.isCompleted) {
                  responseCompleter.complete(true);
                }
              }
            },
          );

          final response = await responseCompleter.future;

          if (response || _isCancelled) {
            if (_isCancelled) {
              print('Download cancelled successfully');
              await tempFile.delete();
              return const Right(true);
            }
            print('File download completed successfully');
            return const Right(true);
          } else {
            retryCount++;
            if (retryCount < maxRetries) {
              print(
                  'Retrying download (attempt ${retryCount + 1} of $maxRetries)');
              await Future.delayed(const Duration(seconds: 1));
              continue;
            }
          }
        } catch (e) {
          print('Error during download attempt ${retryCount + 1}: $e');
          retryCount++;
          if (retryCount < maxRetries) {
            print(
                'Retrying download (attempt ${retryCount + 1} of $maxRetries)');
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
        }
      }

      if (_isCancelled) {
        await tempFile.delete();
        return const Right(true);
      }
      return Left(FileOperationFailure(
          message: 'Failed to download file after $maxRetries attempts'));
    } catch (e) {
      print('Error in downloadFile: $e');
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
      return const Right(true);
    } catch (e) {
      return Left(BluetoothFailure(message: e.toString()));
    }
  }

  Future<void> _listenToConnection(BluetoothConnection connection) async {
    print('Старт...');
    connection.input?.listen(
      (data) {
        if (data.length >= 2) {
          final response = utf8.decode(data);
        }
      },
      onDone: () {
        print('Connection closed');
        _isConnected = false;
        _connection = null;
      },
      onError: (error) {
        print('Connection error: $error');
        _isConnected = false;
        _connection = null;
      },
    );
  }

  /// Запросить обновление архива. Возвращает Stream<String> с состояниями: 'ARCHIVE_UPDATING', 'ARCHIVE_READY'.
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
      print('[Repo] recv ${data.length} bytes: ' +
          data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));

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
}
