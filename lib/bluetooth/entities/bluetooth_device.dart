import 'package:equatable/equatable.dart';

/// Сущность Bluetooth устройства
class BluetoothDevice extends Equatable {
  final String address;
  final String? name;
  final bool isConnected;

  const BluetoothDevice({
    required this.address,
    this.name,
    this.isConnected = false,
  });

  @override
  List<Object?> get props => [address, name, isConnected];

  @override
  String toString() =>
      'BluetoothDevice(address: $address, name: $name, isConnected: $isConnected)';
}
