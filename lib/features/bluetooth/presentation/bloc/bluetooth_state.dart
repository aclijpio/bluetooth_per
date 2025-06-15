import 'package:equatable/equatable.dart';
import '../../domain/entities/bluetooth_device.dart';

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

  const BluetoothConnected({
    required this.device,
    required this.fileList,
  });

  @override
  List<Object?> get props => [device, fileList];
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