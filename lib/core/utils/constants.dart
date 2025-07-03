// Общие константы для проекта

class AppConstants {
  static const String webApiUuid = "595a31f7-ad09-43ff-9a04-1c29bfe795cb";
  static const String webApiBaseUrl = "http://tms.quantor-t.ru:8080";
  static const Duration webApiTimeout = Duration(seconds: 15);
  static const Duration webApiLongTimeout = Duration(seconds: 100040);
  static const int bluetoothScanMaxAttempts = 4;
  static const Duration bluetoothScanAttemptDuration = Duration(seconds: 5);
  static const int bluetoothConnectMaxAttempts = 10;
  static const Duration bluetoothConnectRetryDelay =
      Duration(milliseconds: 500);
  static const Duration bluetoothConnectWaitDelay = Duration(milliseconds: 100);
}
