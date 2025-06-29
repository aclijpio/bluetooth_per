import 'package:equatable/equatable.dart';

class Device extends Equatable {
  final String name;
  final String macAddress;
  final bool isConnected;

  const Device({
    required this.name,
    required this.macAddress,
    this.isConnected = false,
  });

  @override
  List<Object?> get props => [name, macAddress, isConnected];

  @override
  String toString() =>
      'Device(name: $name, macAddress: $macAddress, isConnected: $isConnected)';
}
