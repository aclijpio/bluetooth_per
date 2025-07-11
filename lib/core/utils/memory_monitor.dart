import 'dart:developer' as developer;
import 'dart:io';

class MemoryMonitor {
  static void logMemoryUsage(String tag) {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final info = ProcessInfo.currentRss;
        final mb = (info / (1024 * 1024)).toStringAsFixed(2);
        developer.log('[$tag] Memory usage: ${mb}MB', name: 'MemoryMonitor');
      }
    } catch (e) {
      developer.log('[$tag] Could not get memory info: $e',
          name: 'MemoryMonitor');
    }
  }

  static void logCacheSize(String cacheName, int itemCount, {int? sizeBytes}) {
    final sizeInfo =
        sizeBytes != null ? ', ${(sizeBytes / 1024).toStringAsFixed(2)}KB' : '';
    developer.log('[$cacheName] Cache size: $itemCount items$sizeInfo',
        name: 'MemoryMonitor');
  }

  static void logResourceCreated(String resourceType, String identifier) {
    developer.log('[$resourceType] Created: $identifier',
        name: 'ResourceTracker');
  }

  static void logResourceDisposed(String resourceType, String identifier) {
    developer.log('[$resourceType] Disposed: $identifier',
        name: 'ResourceTracker');
  }
}
