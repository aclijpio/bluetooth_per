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
import '../../../../common/config.dart';

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

  /// Паттерн допустимого имени устройства «Quantor A000AA0000».
  /// Пример: Quantor A123BC, Quantor A123BC1234.
  static final RegExp _quantorNameRegExp =
      RegExp(r'^Quantor [A-Z]\d{3}[A-Z]{2}\d{0,4}$', caseSensitive: false);

  BluetoothRepositoryImpl(this._transport, this._flutterBlueClassic);

  @override
  Future<Either<Failure, List<BluetoothDeviceEntity>>> scanForDevices(
      {void Function(BluetoothDeviceEntity)? onDeviceFound}) async {
    try {
      const int maxAttempts = 1;
      const Duration attemptDuration = Duration(seconds: 50);

      final found = <BluetoothDeviceEntity>[];

      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        _flutterBlueClassic.stopScan(); // на всякий

        final completer = Completer<void>();

        _scanSubscription?.cancel();
        _scanSubscription = _flutterBlueClassic.scanResults.listen((d) {
          final name = d.name ?? '';
          if (!_quantorNameRegExp.hasMatch(name)) return;

          if (!found.any((e) => e.address == d.address)) {
            found.add(BluetoothDeviceEntity(address: d.address, name: d.name));
            if (onDeviceFound != null) {
              onDeviceFound(BluetoothDeviceEntity(address: d.address, name: d.name));
            }
          }

          // как только нашли хотя бы одно, завершаем попытку досрочно
/*
          if (!completer.isCompleted) completer.complete();
*/
        });

        _flutterBlueClassic.startScan();

        await Future.any([
          completer.future,
          Future.delayed(attemptDuration),
        ]);

        _flutterBlueClassic.stopScan();
        await _scanSubscription?.cancel();

        if (found.isNotEmpty) break;

        await Future.delayed(const Duration(seconds: 1));
      }
      return Right(found);
    } catch (e) {
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
    timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!finished) {
        finished = true;
        completer.completeError(TimeoutException('Connection timeout'));
      }
    });
    () async {
      while (attempts < maxAttempts && !finished) {
        try {
          connection = await _flutterBlueClassic.connect(device.address);
          if (connection == null) {
            attempts++;
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          }
          int waitAttempts = 0;
          while (!(connection?.isConnected ?? false) && waitAttempts < 3) {
            await Future.delayed(const Duration(milliseconds: 100));
            waitAttempts++;
          }
          if (!(connection?.isConnected ?? false)) {
            attempts++;
            await Future.delayed(const Duration(milliseconds: 500));
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
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
      if (!finished) {
        finished = true;
        timeoutTimer?.cancel();
        completer.completeError(Exception(
            'Failed to establish connection after $maxAttempts attempts'));
      }
    }();
    final result = await completer.future;
    if (result == null) throw Exception('Connection is null');
    return result;
  }

  @override
  Future<Either<Failure, bool>> connectToDevice(
      BluetoothDeviceEntity device) async {
    if (_isConnecting) {
      return Left(ConnectionFailure(message: 'Connection in progress'));
    }

    try {
      _isConnecting = true;
      _connection = await _connectToDevice(device);

      if (_connection != null && _connection!.isConnected) {
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

      const int memoryLimit = 124 * 1024 * 1024; // 124 МБ
      BytesBuilder memoryBuffer = BytesBuilder();
      bool switchedToFile = false;
      File? tempFile;
      IOSink? sink;
      int receivedBytes = 0;
      int expectedFileSize = 0;
      bool isReadingFileData = false;
      List<int> responseBuffer = [];
      List<int> allReceivedData = [];
      Future<void> flushSink() async {
        if (sink != null) {
          await sink!.flush();
        }
      }

      Future<void> closeSink() async {
        if (sink != null) {
          await sink!.flush();
          await sink!.close();
          sink = null;
        }
      }

      Future<void> addToBufferOrFile(List<int> data) async {
        receivedBytes += data.length;
        allReceivedData.addAll(data);
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
      // --- конец гибридной буферизации ---

      // Reuse уже открытое соединение, если оно есть
      BluetoothConnection? connection = _connection;
      int retryCount = 0;
      const maxRetries = 3;

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
                await flushSink();
                await closeSink();
                responseCompleter.complete(false);
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
                await flushSink();
                await closeSink();
                print('File download completed successfully');
                print('Всего bytes received: ${allReceivedData.length}');
                print('Размер файла: $expectedFileSize');
                print(
                    'Первые 20 numbers: ${allReceivedData.take(20).map((b) => b & 0xFF).join(', ')}');
                print(
                    'Последнии 20 numbers: ${allReceivedData.reversed.take(20).toList().reversed.map((b) => b & 0xFF).join(', ')}');
                // -------- Сохраняем в <documents>/download/quan --------
                String finalPath;
                if (!switchedToFile) {
                  // Всё в памяти
                  final bytes = memoryBuffer.takeBytes();
                  if (sanitizedFileName.toLowerCase().endsWith('.gz')) {
                    try {
                      final rawFile =
                          File(p.join(downloadDir.path, finalFileName));
                      await rawFile.writeAsBytes(gzip.decode(bytes));
                      finalPath = rawFile.path;
                      await ArchiveSyncManager.addPending(finalPath);
                    } catch (e) {
                      print('Error while decompressing: $e');
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
                  // Данные были сброшены в файл
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
                      print('Error while decompressing: $e');
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
                        print('Cannot move file to downloads: $e');
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
              print('Error during file download: $error');
              await flushSink();
              await closeSink();
              if (!responseCompleter.isCompleted) {
                responseCompleter.completeError(error);
              }
            },
            onDone: () async {
              print(
                  'Connection closed, received $receivedBytes of $expectedFileSize bytes');
              await flushSink();
              await closeSink();
              if (receivedBytes < expectedFileSize && !_isCancelled) {
                print(
                    'Connection closed before download completed, will retry');
                if (!responseCompleter.isCompleted) {
                  responseCompleter.complete(false);
                }
              } else if (!responseCompleter.isCompleted) {
                responseCompleter.complete(true);
              }
            },
          );

          final response = await responseCompleter.future;

          if (response || _isCancelled) {
            if (_isCancelled) {
              print('Download cancelled successfully');
              await tempFile?.delete();
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
        await tempFile?.delete();
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

  @override
  void cancelScan() {
    _isCancelled = true;
    _flutterBlueClassic.stopScan();
    _scanSubscription?.cancel();
  }
}
