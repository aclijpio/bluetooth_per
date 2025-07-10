import 'package:equatable/equatable.dart';

class Device extends Equatable {
  final String name;
  final String macAddress;

  const Device({required this.name, required this.macAddress});

  @override
  List<Object?> get props => [name, macAddress];
}
