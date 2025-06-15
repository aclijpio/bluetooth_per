import 'package:equatable/equatable.dart';

class BluetoothDeviceEntity extends Equatable {
  final String address;
  final String? name;
  final bool isConnected;

  const BluetoothDeviceEntity({
    required this.address,
    this.name,
    this.isConnected = false,
  });

  @override
  List<Object?> get props => [address, name, isConnected];
} 