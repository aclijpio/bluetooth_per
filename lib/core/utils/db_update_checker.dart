import 'package:shared_preferences/shared_preferences.dart';

class DbUpdateChecker {
  DbUpdateChecker._();

  static const _lastSyncKey = 'db_last_sync';

  /// Через сколько времени нужно пересоздавать архив
  static const Duration maxAge = Duration(hours: 24);

  static Future<DateTime?> _lastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastSyncKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<bool> isStale() async {
    final last = await _lastSync();
    if (last == null) return true;
    return DateTime.now().difference(last) > maxAge;
  }

  static Future<void> markNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }
}
