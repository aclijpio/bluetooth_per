import 'dart:async';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/bluetooth_device.dart';
import '../../domain/repositories/bluetooth_repository.dart';

class BluetoothRepositoryImpl implements BluetoothRepository {
  final FlutterBlueClassic _flutterBlueClassic;
  BluetoothConnection? _connection;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;

  BluetoothRepositoryImpl(this._flutterBlueClassic);

  @override
  Future<Either<Failure, List<BluetoothDeviceEntity>>> scanForDevices() async {
    try {
      final devices = <BluetoothDeviceEntity>[];
      final completer = Completer<List<BluetoothDeviceEntity>>();

      _scanSubscription?.cancel();
      _scanSubscription = _flutterBlueClassic.scanResults.listen((device) {
        devices.add(BluetoothDeviceEntity(
          address: device.address,
          name: device.name,
        ));
      });

      // Scan for 10 seconds
      await Future.delayed(const Duration(seconds: 10));
      _scanSubscription?.cancel();
      completer.complete(devices);

      return Right(await completer.future);
    } catch (e) {
      return Left(BluetoothFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> connectToDevice(BluetoothDeviceEntity device) async {
    try {
      _connection = await _flutterBlueClassic.connect(device.address);
      return const Right(true);
    } catch (e) {
      return Left(ConnectionFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> disconnectFromDevice(BluetoothDeviceEntity device) async {
    try {
      if (_connection != null) {
        _connection!.dispose();
        _connection = null;
      }
      return const Right(true);
    } catch (e) {
      return Left(ConnectionFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getFileList() async {
    try {
      if (_connection == null) {
        return Left(ConnectionFailure(message: 'Not connected to any device'));
      }

      final completer = Completer<List<String>>();
      _connection?.input?.listen((data) {
        final response = String.fromCharCodes(data);
        completer.complete(response.split(','));
      });

      _connection?.writeString('LIST_FILES');
      return Right(await completer.future);
    } catch (e) {
      return Left(FileOperationFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> downloadFile(String fileName) async {
    try {
      if (_connection == null) {
        return Left(ConnectionFailure(message: 'Not connected to any device'));
      }

      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        return Left(FileOperationFailure(message: 'Could not access storage'));
      }

      final file = File('${directory.path}/$fileName');
      final sink = file.openWrite();

      _connection?.writeString('GET_FILE:$fileName');
      _connection?.input?.listen(
        (data) => sink.add(data),
        onDone: () => sink.close(),
        onError: (error) => sink.close(),
      );

      return const Right(true);
    } catch (e) {
      return Left(FileOperationFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isBluetoothEnabled() async {
    try {
      final state = await _flutterBlueClassic.adapterStateNow;
      return Right(state == BluetoothAdapterState.on);
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
} 