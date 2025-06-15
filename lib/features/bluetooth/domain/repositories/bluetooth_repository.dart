import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/bluetooth_device.dart';

abstract class BluetoothRepository {
  Future<Either<Failure, List<BluetoothDeviceEntity>>> scanForDevices();
  Future<Either<Failure, bool>> connectToDevice(BluetoothDeviceEntity device);
  Future<Either<Failure, bool>> disconnectFromDevice(BluetoothDeviceEntity device);
  Future<Either<Failure, List<String>>> getFileList();
  Future<Either<Failure, bool>> downloadFile(String fileName);
  Future<Either<Failure, bool>> isBluetoothEnabled();
  Future<Either<Failure, bool>> enableBluetooth();
} 