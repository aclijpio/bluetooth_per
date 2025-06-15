import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({
    required this.message,
    this.code,
  });

  @override
  List<Object?> get props => [message, code];
}

class BluetoothFailure extends Failure {
  const BluetoothFailure({
    required String message,
    String? code,
  }) : super(message: message, code: code);
}

class ConnectionFailure extends Failure {
  const ConnectionFailure({
    required String message,
    String? code,
  }) : super(message: message, code: code);
}

class FileOperationFailure extends Failure {
  const FileOperationFailure({
    required String message,
    String? code,
  }) : super(message: message, code: code);
} 