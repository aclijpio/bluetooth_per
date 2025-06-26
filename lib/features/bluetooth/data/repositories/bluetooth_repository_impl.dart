import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/failures.dart';
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
  List<String> _fileList = [];
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isCancelled = false;
  StreamSubscription? _downloadSubscription;

  BluetoothRepositoryImpl(this._transport, this._flutterBlueClassic);

  @override
  Future<Either<Failure, List<BluetoothDeviceEntity>>> scanForDevices() async {
    try {
      _flutterBlueClassic.stopScan();

      final devices = <BluetoothDeviceEntity>[];

      _scanSubscription?.cancel();
      _scanSubscription = _flutterBlueClassic.scanResults.listen((device) {
        if (!devices.any((d) => d.address == device.address)) {
          devices.add(
            BluetoothDeviceEntity(
              address: device.address,
              name: device.name,
            ),
          );
        }
        if ((device.name ?? '').toLowerCase().contains('quantor')) {
          _flutterBlueClassic.stopScan();
          _scanSubscription?.cancel();
        }
      });

      _flutterBlueClassic.startScan();
      await Future.delayed(const Duration(seconds: 10));

      _flutterBlueClassic.stopScan();
      await _scanSubscription?.cancel();

      return Right(devices);
    } catch (e) {
      return Left(BluetoothFailure(message: e.toString()));
    }
  }

  Future<BluetoothConnection> _connectToDevice(
      BluetoothDeviceEntity device) async {
    print('Connecting to device: ${device.address}');
    BluetoothConnection? connection;
    int attempts = 0;
    const maxAttempts = 10;
    // Несколько попыток подключения
    while (attempts < maxAttempts) {
      try {
        connection = await _flutterBlueClassic.connect(device.address);

        if (connection == null) {
          attempts++;
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        int waitAttempts = 0;
        while (!connection.isConnected && waitAttempts < 3) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitAttempts++;
        }

        if (!connection.isConnected) {
          attempts++;
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        return connection;
      } catch (e) {
        attempts++;
        if (attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
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
    if (_connection == null || !_connection!.isConnected) {
      return Left(ConnectionFailure(message: 'Not connected to device'));
    }

    try {
      print('Getting file list...');
      final completer = Completer<List<String>>();
      List<int> buffer = [];
      bool isReadingFileList = false;
      int expectedFileCount = 0;
      int receivedFileCount = 0;
      List<String> receivedFiles = [];

      final subscription = _connection!.input?.listen(
        (data) {
          print('d raw data: ${data.length} байтов');
          buffer.addAll(data);

          while (buffer.isNotEmpty) {
            if (!isReadingFileList) {
              if (buffer.length >= 4) {
                final countBytes = Uint8List.fromList(buffer.sublist(0, 4));
                expectedFileCount =
                    ByteData.view(countBytes.buffer).getInt32(0, Endian.big);
                buffer = buffer.sublist(4);
                isReadingFileList = true;
                print('$expectedFileCount files');
              } else {
                break;
              }
            } else {
              if (buffer.length >= 2) {
                final lengthBytes = Uint8List.fromList(buffer.sublist(0, 2));
                final nameLength =
                    ByteData.view(lengthBytes.buffer).getInt16(0, Endian.big);

                if (buffer.length >= 2 + nameLength) {
                  final nameBytes = buffer.sublist(2, 2 + nameLength);
                  final fileName = utf8.decode(nameBytes);
                  receivedFiles.add(fileName);
                  buffer = buffer.sublist(2 + nameLength);
                  receivedFileCount++;
                  print('Received file name: $fileName');

                  if (receivedFileCount == expectedFileCount) {
                    print('Received all files: $receivedFiles');
                    _fileList = receivedFiles;
                    completer.complete(receivedFiles);
                    isReadingFileList = false;
                    buffer.clear();
                  }
                } else {
                  break;
                }
              } else {
                break;
              }
            }
          }
        },
        onError: (error) {
          print('Error in input stream: $error');
          completer.completeError(error);
        },
        onDone: () {
          print('Input stream closed');
          if (!completer.isCompleted) {
            completer.complete(_fileList);
          }
        },
      );

      _connection!.output.add(BluetoothProtocol.listFilesCmd());

      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Server response timeout');
        },
      );

      subscription?.cancel();
      return Right(result);
    } catch (e) {
      print('Error getting file list: $e');
      return Left(ConnectionFailure(message: e.toString()));
    }
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
      final file = File('${directory.path}/$fileName');
      print('Will save file to: ${file.path}');

      bool isDbFile = fileName.toLowerCase().endsWith('.db') ||
          fileName.toLowerCase().endsWith('.db.gz');

      final sink = file.openWrite();
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

          print('Sending GET_FILE request');
          connection.output.add(BluetoothProtocol.getFileCmd(fileName));

          final responseCompleter = Completer<bool>();

          _downloadSubscription = connection.input?.listen(
            (data) async {
              if (_isCancelled) {
                print('Download cancelled');
                sink.close();
                connection?.close();
                responseCompleter.complete(false);
                return;
              }

              print('Received data chunk: ${data.length} bytes');

              if (!isReadingFileData) {
                responseBuffer.addAll(data);

                if (responseBuffer.length >= 1) {
                  final response = responseBuffer[0];
                  print('Server response byte: ${response.toRadixString(16)}');

                  if (response == 0) {
                    print('Server reported file not found');
                    sink.close();
                    connection?.close();
                    responseCompleter.complete(false);
                    return;
                  }

                  responseBuffer = responseBuffer.sublist(1);

                  if (responseBuffer.length >= 8) {
                    final sizeBytes =
                        Uint8List.fromList(responseBuffer.sublist(0, 8));
                    expectedFileSize =
                        ByteData.view(sizeBytes.buffer).getInt64(0, Endian.big);
                    print('File size from server: $expectedFileSize bytes');
                    responseBuffer = responseBuffer.sublist(8);
                    isReadingFileData = true;

                    if (responseBuffer.isNotEmpty) {
                      sink.add(responseBuffer);
                      receivedBytes += responseBuffer.length;
                      allReceivedData.addAll(responseBuffer);

                      final progress = receivedBytes / expectedFileSize;
                      onProgress?.call(progress, expectedFileSize);
                      responseBuffer.clear();
                    }
                  }
                }
              } else {
                sink.add(data);
                receivedBytes += data.length;
                allReceivedData.addAll(data);

                final progress = receivedBytes / expectedFileSize;

                onProgress?.call(progress, expectedFileSize);

                print(
                    'Download progress: $receivedBytes / $expectedFileSize bytes');

                if (receivedBytes >= expectedFileSize) {
                  print('File download completed successfully');

                  print('Всего bytes received: ${allReceivedData.length}');
                  print('Размер файла: $expectedFileSize');
                  print(
                      'Первые 20 numbers: ${allReceivedData.take(20).map((b) => b & 0xFF).join(', ')}');
                  print(
                      'Последнии 20 numbers: ${allReceivedData.reversed.take(20).toList().reversed.map((b) => b & 0xFF).join(', ')}');

                  sink.close();
                  // Соединение оставляем открытым — его закроем при явном Disconnect

                  // Если файл пришёл в gzip-формате, распаковываем его
                  String finalPath = file.path;
                  if (fileName.toLowerCase().endsWith('.gz')) {
                    try {
                      final rawFileName = fileName.replaceAll(
                          RegExp(r'\.gz$', caseSensitive: false), '');
                      final rawFile = File('${directory.path}/$rawFileName');
                      await file
                          .openRead()
                          .transform(gzip.decoder)
                          .pipe(rawFile.openWrite());
                      finalPath = rawFile.path;
                    } catch (e) {
                      print('Error while decompressing: $e');
                    }
                  }

                  onComplete?.call(finalPath);

                  if (!responseCompleter.isCompleted) {
                    responseCompleter.complete(true);
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

                sink.close();

                // Распаковка, если нужно
                String finalPath = file.path;
                if (fileName.toLowerCase().endsWith('.gz')) {
                  try {
                    final rawFileName = fileName.replaceAll(
                        RegExp(r'\.gz$', caseSensitive: false), '');
                    final rawFile = File('${directory.path}/$rawFileName');
                    await file
                        .openRead()
                        .transform(gzip.decoder)
                        .pipe(rawFile.openWrite());
                    finalPath = rawFile.path;
                  } catch (e) {
                    print('Error while decompressing (onDone): $e');
                  }
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
              await file.delete();
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

      sink.close();
      connection?.close();
      if (_isCancelled) {
        await file.delete();
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
    final subscription = _connection!.input?.listen((data) {
      // debug log of raw packet
      print('[Repo] recv ${data.length} bytes: ' +
          data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));

      if (BluetoothProtocol.isArchiveUpdating(data)) {
        print('[Repo] -> ARCHIVE_UPDATING');
        controller.add('ARCHIVE_UPDATING');
      } else if (BluetoothProtocol.isArchiveReady(data)) {
        print('[Repo] -> ARCHIVE_READY');
        controller.add('ARCHIVE_READY');
        completer.complete();
      } else {
        print('[Repo] unknown message');
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
