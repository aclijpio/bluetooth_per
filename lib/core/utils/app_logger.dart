import 'package:logger/logger.dart';
import '../config/app_strings.dart';

/// Centralized application logging system
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
  );

  AppLogger._();

  /// Log debug information (development only)
  static void debug(String message, [String? tag]) {
    _logger.d('${tag != null ? '$tag ' : ''}$message');
  }

  /// Log general information
  static void info(String message, [String? tag]) {
    _logger.i('${tag != null ? '$tag ' : ''}$message');
  }

  /// Log warnings
  static void warning(String message, [String? tag]) {
    _logger.w('${tag != null ? '$tag ' : ''}$message');
  }

  /// Log errors
  static void error(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    _logger.e('${tag != null ? '$tag ' : ''}$message', error: error, stackTrace: stackTrace);
  }

  /// Log critical errors
  static void fatal(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    _logger.f('${tag != null ? '$tag ' : ''}$message', error: error, stackTrace: stackTrace);
  }

  // Predefined logging methods for specific components
  
  /// Device Flow logging
  static void deviceFlow(String message) {
    info(message, AppStrings.logDeviceFlow);
  }

  /// Bluetooth operations logging
  static void bluetooth(String message) {
    info(message, AppStrings.logBluetoothRepo);
  }

  /// Network operations logging
  static void network(String message) {
    info(message, AppStrings.logServerConnection);
  }

  /// Permission operations logging
  static void permissions(String message) {
    info(message, AppStrings.logPermissions);
  }

  /// Database operations logging
  static void database(String message) {
    info(message, AppStrings.logMainData);
  }

  /// Progress tracking (only essential progress events)
  static void progress(String message) {
    debug('${AppStrings.progressLabel}$message');
  }
}