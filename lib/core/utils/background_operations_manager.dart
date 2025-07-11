import 'package:wakelock_plus/wakelock_plus.dart';

class BackgroundOperationsManager {
  static bool _isWakeLockEnabled = false;
  static int _activeLocks = 0;

  static Future<void> enableWakeLock() async {
    if (!_isWakeLockEnabled) {
      try {
        await WakelockPlus.enable();
        _isWakeLockEnabled = true;
        print('[BackgroundOperations] Wake lock enabled');
      } catch (e) {
        print('[BackgroundOperations] Failed to enable wake lock: $e');
      }
    }
  }

  static Future<void> disableWakeLock() async {
    if (_isWakeLockEnabled && _activeLocks <= 1) {
      try {
        await WakelockPlus.disable();
        _isWakeLockEnabled = false;
        _activeLocks = 0;
        print('[BackgroundOperations] Wake lock disabled');
      } catch (e) {
        print('[BackgroundOperations] Failed to disable wake lock: $e');
      }
    } else {
      _activeLocks = (_activeLocks - 1).clamp(0, 999);
    }
  }

  static bool get isWakeLockEnabled => _isWakeLockEnabled;

  static Future<void> ensureWakeLockForOperation() async {
    _activeLocks++;
    await enableWakeLock();
  }

  static Future<void> releaseWakeLockAfterOperation() async {
    await disableWakeLock();
  }

  static Future<void> forceReleaseAllWakeLocks() async {
    _activeLocks = 0;
    if (_isWakeLockEnabled) {
      try {
        await WakelockPlus.disable();
        _isWakeLockEnabled = false;
        print('[BackgroundOperations] All wake locks force released');
      } catch (e) {
        print('[BackgroundOperations] Failed to force release wake locks: $e');
      }
    }
  }
}
