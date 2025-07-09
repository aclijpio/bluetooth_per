/// Application timeout configurations
class AppTimeouts {
  AppTimeouts._();

  // Connection timeouts
  static const Duration bluetoothConnectionTimeout = Duration(seconds: 30);
  static const Duration bluetoothScanAttemptTimeout = Duration(seconds: 50);
  static const Duration bluetoothScanTimeout = Duration(seconds: 15);
  static const Duration archiveReadyTimeout = Duration(seconds: 10);

  // Network timeouts
  static const Duration httpRequestTimeout = Duration(seconds: 15);
  static const Duration longHttpRequestTimeout = Duration(seconds: 100040);

  // UI & Animation delays
  static const Duration shortDelay = Duration(milliseconds: 100);
  static const Duration mediumDelay = Duration(milliseconds: 500);
  static const Duration longDelay = Duration(seconds: 1);
  static const Duration veryLongDelay = Duration(seconds: 2);

  // Database & File operations
  static const Duration dbUpdateMaxAge = Duration(hours: 24);

  // Retry intervals
  static Duration getRetryDelay(int attempt) => Duration(seconds: 1 << attempt); // 1, 2, 4 seconds
}