import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/bluetooth_device.dart';

typedef DownloadProgressCallback = void Function(
    double progress, int? fileSize);
typedef DownloadCompleteCallback = void Function(String filePath);

abstract class BluetoothRepository {
  Future<Either<Failure, List<BluetoothDeviceEntity>>> scanForDevices(
      {void Function(BluetoothDeviceEntity)? onDeviceFound});
  Future<Either<Failure, bool>> connectToDevice(BluetoothDeviceEntity device);
  Future<Either<Failure, bool>> disconnectFromDevice(
      BluetoothDeviceEntity device);
  Future<Either<Failure, List<String>>> getFileList();
  Future<Either<Failure, bool>> downloadFile(
    String fileName,
    BluetoothDeviceEntity device, {
    DownloadProgressCallback? onProgress,
    DownloadCompleteCallback? onComplete,
  });
  Future<Either<Failure, bool>> cancelDownload();
  Future<Either<Failure, bool>> isBluetoothEnabled();
  Future<Either<Failure, bool>> enableBluetooth();

  /// Запросить обновление архива. Возвращает Stream<String> с состояниями: 'ARCHIVE_UPDATING', 'ARCHIVE_READY'.
  Stream<String> requestArchiveUpdate();

  void cancelScan();
}
