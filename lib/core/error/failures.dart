import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final dynamic originalError;

  const Failure({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  List<Object?> get props => [message, code, originalError];
}

// General failures
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.code,
    super.originalError,
  });
}

class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.code,
    super.originalError,
  });
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.originalError,
  });
}

// Bluetooth specific failures
class BluetoothFailure extends Failure {
  const BluetoothFailure({
    required super.message,
    super.code,
    super.originalError,
  });
}

class BluetoothNotAvailableFailure extends BluetoothFailure {
  const BluetoothNotAvailableFailure()
      : super(
          message: 'Bluetooth is not available on this device',
          code: 'BT_NOT_AVAILABLE',
        );
}

class BluetoothNotEnabledFailure extends BluetoothFailure {
  const BluetoothNotEnabledFailure()
      : super(
          message: 'Bluetooth is not enabled',
          code: 'BT_NOT_ENABLED',
        );
}

class BluetoothPermissionFailure extends BluetoothFailure {
  const BluetoothPermissionFailure()
      : super(
          message: 'Bluetooth permissions are not granted',
          code: 'BT_PERMISSION_DENIED',
        );
}

class BluetoothConnectionFailure extends BluetoothFailure {
  const BluetoothConnectionFailure({
    super.message = 'Failed to connect to Bluetooth device',
    super.code = 'BT_CONNECTION_FAILED',
    super.originalError,
  });
}

class BluetoothDeviceNotFoundFailure extends BluetoothFailure {
  const BluetoothDeviceNotFoundFailure()
      : super(
          message: 'Bluetooth device not found',
          code: 'BT_DEVICE_NOT_FOUND',
        );
}

// File system failures
class FileSystemFailure extends Failure {
  const FileSystemFailure({
    required super.message,
    super.code,
    super.originalError,
  });
}

class FileNotFoundFailure extends FileSystemFailure {
  const FileNotFoundFailure(String path)
      : super(
          message: 'File not found: $path',
          code: 'FILE_NOT_FOUND',
        );
}

class FilePermissionFailure extends FileSystemFailure {
  const FilePermissionFailure(String path)
      : super(
          message: 'Permission denied for file: $path',
          code: 'FILE_PERMISSION_DENIED',
        );
}

class StoragePermissionFailure extends FileSystemFailure {
  const StoragePermissionFailure()
      : super(
          message: 'Storage permission is required',
          code: 'STORAGE_PERMISSION_DENIED',
        );
}

// Database failures
class DatabaseFailure extends Failure {
  const DatabaseFailure({
    required super.message,
    super.code,
    super.originalError,
  });
}

class DatabaseConnectionFailure extends DatabaseFailure {
  const DatabaseConnectionFailure(String path)
      : super(
          message: 'Failed to connect to database: $path',
          code: 'DB_CONNECTION_FAILED',
        );
}

class DatabaseQueryFailure extends DatabaseFailure {
  const DatabaseQueryFailure(String query, Object error)
      : super(
          message: 'Database query failed: $query',
          code: 'DB_QUERY_FAILED',
          originalError: error,
        );
}

// Data validation failures
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.originalError,
  });
}

class InvalidDataFailure extends ValidationFailure {
  const InvalidDataFailure(String details)
      : super(
          message: 'Invalid data: $details',
          code: 'INVALID_DATA',
        );
}

// Timeout failures
class TimeoutFailure extends Failure {
  final Duration timeout;

  const TimeoutFailure({
    required super.message,
    required this.timeout,
    super.code = 'TIMEOUT',
    super.originalError,
  });

  @override
  List<Object?> get props => [...super.props, timeout];
}

// Extension methods for better error handling
extension FailureExtensions on Failure {
  bool get isNetworkError =>
      this is NetworkFailure ||
      this is ServerFailure ||
      (this is TimeoutFailure && code == 'NETWORK_TIMEOUT');

  bool get isBluetoothError => this is BluetoothFailure;

  bool get isFileSystemError => this is FileSystemFailure;

  bool get isDatabaseError => this is DatabaseFailure;

  bool get isPermissionError =>
      this is BluetoothPermissionFailure ||
      this is FilePermissionFailure ||
      this is StoragePermissionFailure;

  bool get isRecoverable =>
      this is BluetoothNotEnabledFailure ||
      this is BluetoothPermissionFailure ||
      this is StoragePermissionFailure ||
      this is NetworkFailure;
}
