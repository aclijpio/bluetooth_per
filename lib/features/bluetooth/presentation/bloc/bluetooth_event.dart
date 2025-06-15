import 'package:equatable/equatable.dart';
import '../../domain/entities/bluetooth_device.dart';

abstract class BluetoothEvent extends Equatable {
  const BluetoothEvent();

  @override
  List<Object?> get props => [];
}

class CheckBluetoothStatus extends BluetoothEvent {
  const CheckBluetoothStatus();
}

class EnableBluetooth extends BluetoothEvent {
  const EnableBluetooth();
}

class StartScanning extends BluetoothEvent {
  const StartScanning();
}

class StopScanning extends BluetoothEvent {
  const StopScanning();
}

class ConnectToDevice extends BluetoothEvent {
  final BluetoothDeviceEntity device;

  const ConnectToDevice(this.device);

  @override
  List<Object?> get props => [device];
}

class DisconnectFromDevice extends BluetoothEvent {
  final BluetoothDeviceEntity device;

  const DisconnectFromDevice(this.device);

  @override
  List<Object?> get props => [device];
}

class GetFileList extends BluetoothEvent {
  const GetFileList();
}

class DownloadFile extends BluetoothEvent {
  final String fileName;

  const DownloadFile(this.fileName);

  @override
  List<Object?> get props => [fileName];
} 