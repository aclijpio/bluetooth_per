import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/bluetooth_device.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../presentation/bloc/bluetooth_bloc.dart';

class BluetoothRepositoryImpl implements BluetoothRepository {
  final FlutterBlueClassic _flutterBlueClassic;
  BluetoothConnection? _connection;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  List<String> _fileList = [];
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isCancelled = false;
  StreamSubscription? _downloadSubscription;

  BluetoothRepositoryImpl(this._flutterBlueClassic);

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
      });

      _flutterBlueClassic.startScan();
      await Future.delayed(const Duration(seconds: 2));

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

    while (attempts < maxAttempts) {
      try {
        print('Connection attempt ${attempts + 1} of $maxAttempts');
        connection = await _flutterBlueClassic.connect(device.address);

        if (connection == null) {
          print(
              'Connection attempt ${attempts + 1} failed: connection is null');
          attempts++;
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        print('Connection established: ${connection.isConnected}');

        int waitAttempts = 0;
        while (!connection.isConnected && waitAttempts < 3) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitAttempts++;
          print('Waiting for connection to be ready: attempt $waitAttempts');
        }

        if (!connection.isConnected) {
          print(
              'Connection attempt ${attempts + 1} failed: connection not ready');
          attempts++;
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        print('Connection successfully established on attempt ${attempts + 1}');
        return connection;
      } catch (e) {
        print('Connection attempt ${attempts + 1} failed with error: $e');
        attempts++;
        if (attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    throw Exception('Failed to establish connection after $maxAttempts attempts');
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
        return Left(ConnectionFailure(message: 'Failed to establish connection'));
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
          print('Received raw data: ${data.length} bytes');
          buffer.addAll(data);

          while (buffer.isNotEmpty) {
            if (!isReadingFileList) {
              if (buffer.length >= 4) {
                final countBytes = Uint8List.fromList(buffer.sublist(0, 4));
                expectedFileCount =
                    ByteData.view(countBytes.buffer).getInt32(0, Endian.big);
                buffer = buffer.sublist(4);
                isReadingFileList = true;
                print('Expecting $expectedFileCount files');
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

      print('Sending LIST_FILES request');
      _sendWriteUTF('LIST_FILES');

      final result = await completer.future.timeout(
        const Duration(seconds: 5),
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
        print('Message sent successfully via writeUTF: $message');
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

      print('Sending data (hex):');
      print(
          'Length bytes: ${bytes[0].toRadixString(16).padLeft(2, '0')} ${bytes[1].toRadixString(16).padLeft(2, '0')}');
      print(
          'Data bytes: ${encoded.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      print(
          'Full message: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      print('Original message: $message');

      if (connection.isConnected) {
        connection.output.add(bytes);
        print('Message sent successfully via writeUTF: $message');
      } else {
        print('Connection lost before sending message');
      }
    } catch (e) {
      print('Error sending message via writeUTF: $e');
    }
  }

  void _sendWriteWithConnection(
      BluetoothConnection connection, String message) {
    if (!connection.isConnected) {
      print('Cannot send message: connection is not established');
      return;
    }

    try {
      final encoded = utf8.encode(message);
      final bytes = Uint8List.fromList(encoded);

      print('Sending data (hex):');
      print(
          'Data bytes: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      print('Original message: $message');

      if (connection.isConnected) {
        connection.output.add(bytes);
        print('Message sent successfully via write: $message');
      } else {
        print('Connection lost before sending message');
      }
    } catch (e) {
      print('Error sending message via write: $e');
    }
  }

  void _sendWriteWithResponseWithConnection(
      BluetoothConnection connection, String message) {
    if (!connection.isConnected) {
      print('Cannot send message: connection is not established');
      return;
    }

    try {
      final encoded = utf8.encode(message);
      final bytes = Uint8List.fromList(encoded);

      print('Sending data (hex):');
      print(
          'Data bytes: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      print('Original message: $message');

      if (connection.isConnected) {
        connection.output.add(bytes);
        print('Message sent successfully via writeWithResponse: $message');
      } else {
        print('Connection lost before sending message');
      }
    } catch (e) {
      print('Error sending message via writeWithResponse: $e');
    }
  }

  @override
  Future<Either<Failure, bool>> downloadFile(String fileName, BluetoothDeviceEntity device, {DownloadProgressCallback? onProgress, DownloadCompleteCallback? onComplete,}) async {
    try {
      _isCancelled = false;
      print('Starting file download for: $fileName');
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      print('Will save file to: ${file.path}');

      bool isDbFile = fileName.toLowerCase().endsWith('.db');

      final sink = file.openWrite();
      print('File sink opened');

      BluetoothConnection? connection;
      int retryCount = 0;
      const maxRetries = 3;
      int receivedBytes = 0;
      int expectedFileSize = 0;
      bool isReadingFileData = false;
      List<int> responseBuffer = [];
      List<int> allReceivedData = [];
      bool isFirstDataChunk = true;

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
          _sendWriteUTFWithConnection(connection, 'GET_FILE:$fileName');

          final responseCompleter = Completer<bool>();

          _downloadSubscription = connection.input?.listen(
            (data) {
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
                      if (isFirstDataChunk) {
                        isFirstDataChunk = false;
                        if (responseBuffer.length > 9) {
                          final actualData = responseBuffer.sublist(9);
                          sink.add(actualData);
                          receivedBytes += actualData.length;
                          allReceivedData.addAll(actualData);

                          final progress = receivedBytes / expectedFileSize;
                          print(
                              'Progress update: $progress (${receivedBytes}/${expectedFileSize})');
                          onProgress?.call(progress, expectedFileSize);
                        }
                      } else {
                        sink.add(responseBuffer);
                        receivedBytes += responseBuffer.length;
                        allReceivedData.addAll(responseBuffer);

                        final progress = receivedBytes / expectedFileSize;
                        print(
                            'Progress update: $progress (${receivedBytes}/${expectedFileSize})');
                        onProgress?.call(progress, expectedFileSize);
                      }
                      responseBuffer.clear();

                      if (connection != null && connection.isConnected) {
                        _sendWriteUTFWithConnection(connection, 'ACK');
                      }
                    }
                  }
                }
              } else {
                if (isFirstDataChunk) {
                  isFirstDataChunk = false;
                  if (data.length > 9) {
                    final actualData = data.sublist(9);
                    sink.add(actualData);
                    receivedBytes += actualData.length;
                    allReceivedData.addAll(actualData);

                    final progress = receivedBytes / expectedFileSize;
                    print(
                        'Progress update: $progress (${receivedBytes}/${expectedFileSize})');
                    onProgress?.call(progress, expectedFileSize);
                  }
                } else {
                  sink.add(data);
                  receivedBytes += data.length;
                  allReceivedData.addAll(data);

                  final progress = receivedBytes / expectedFileSize;
                  print(
                      'Progress update: $progress (${receivedBytes}/${expectedFileSize})');
                  onProgress?.call(progress, expectedFileSize);
                }

                print(
                    'Download progress: $receivedBytes / $expectedFileSize bytes');

                if (receivedBytes % 102400 < data.length &&
                    connection != null &&
                    connection.isConnected) {
                  _sendWriteUTFWithConnection(connection, 'ACK');
                }

                if (receivedBytes >= expectedFileSize) {
                  print('File download completed successfully');

                  print('\nDownload Summary:');
                  print('Total bytes received: ${allReceivedData.length}');
                  print('Expected file size: $expectedFileSize');
                  print(
                      'First 20 numbers: ${allReceivedData.take(20).map((b) => b & 0xFF).join(', ')}');
                  print(
                      'Last 20 numbers: ${allReceivedData.reversed.take(20).toList().reversed.map((b) => b & 0xFF).join(', ')}');

                  sink.close();
                  connection?.close();

                  if (isDbFile) {
                    print('Database file downloaded: ${file.path}');
                  }

                  onComplete?.call(file.path);

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
            onDone: () {
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

                onComplete?.call(file.path);

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
    print('Starting to listen to connection...');
    connection.input?.listen(
      (data) {
        print('Received data (hex):');
        print(
            'Raw bytes: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        print('As string: ${utf8.decode(data)}');

        if (data.length >= 2) {
          final response = utf8.decode(data);
          print('Processing response: $response');
          print('Response received: $response');
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
}
