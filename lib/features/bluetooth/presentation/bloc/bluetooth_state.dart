import 'package:equatable/equatable.dart';

import '../../domain/entities/bluetooth_device.dart';
import '../../domain/entities/file_download_info.dart';

abstract class BluetoothState extends Equatable {
  const BluetoothState();

  @override
  List<Object?> get props => [];
}

class BluetoothInitial extends BluetoothState {}

class BluetoothLoading extends BluetoothState {}

class BluetoothEnabled extends BluetoothState {}

class BluetoothDisabled extends BluetoothState {}

class BluetoothScanning extends BluetoothState {
  final List<BluetoothDeviceEntity> devices;

  const BluetoothScanning(this.devices);

  @override
  List<Object?> get props => [devices];
}

class BluetoothConnected extends BluetoothState {
  final BluetoothDeviceEntity device;
  final List<String> fileList;
  final Map<String, FileDownloadInfo> downloadInfo;

  const BluetoothConnected({
    required this.device,
    required this.fileList,
    this.downloadInfo = const {},
  });

  @override
  List<Object?> get props => [device, fileList, downloadInfo];
}

class BluetoothDisconnected extends BluetoothState {}

class BluetoothError extends BluetoothState {
  final String message;

  const BluetoothError(this.message);

  @override
  List<Object?> get props => [message];
}

class FileDownloading extends BluetoothState {
  final String fileName;
  final double progress;

  const FileDownloading({
    required this.fileName,
    required this.progress,
  });

  @override
  List<Object?> get props => [fileName, progress];
}

class FileDownloaded extends BluetoothState {
  final String fileName;
  final String filePath;

  const FileDownloaded({
    required this.fileName,
    required this.filePath,
  });

  @override
  List<Object?> get props => [fileName, filePath];
}

class BluetoothNavigateToWebExport extends BluetoothState {
  const BluetoothNavigateToWebExport();
}

class ArchiveUpdatingState extends BluetoothConnected {
  const ArchiveUpdatingState({
    required BluetoothDeviceEntity device,
    required List<String> fileList,
    required Map<String, FileDownloadInfo> downloadInfo,
  }) : super(
          device: device,
          fileList: fileList,
          downloadInfo: downloadInfo,
        );
}

class ArchiveReadyState extends BluetoothConnected {
  const ArchiveReadyState({
    required BluetoothDeviceEntity device,
    required List<String> fileList,
    required Map<String, FileDownloadInfo> downloadInfo,
  }) : super(
          device: device,
          fileList: fileList,
          downloadInfo: downloadInfo,
        );
}
