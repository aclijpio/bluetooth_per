import 'dart:async';
import 'dart:io';

import 'package:external_path/external_path.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../config.dart';

enum LogLevel {
  debug('ОТЛАДКА'),
  info('ИНФО'),
  warning('ПРЕДУПР'),
  error('ОШИБКА');

  const LogLevel(this.displayName);
  final String displayName;
}

/// Элегантный и оптимизированный менеджер логирования
///
/// Основные возможности:
/// - Автоматическая ротация логов по размеру и возрасту
/// - Асинхронная запись в файл для оптимальной производительности
/// - Thread-safe операции
/// - Управление размером и количеством файлов логов
class LogManager {
  LogManager._();

  static LogManager? _instance;
  static LogManager get instance => _instance ??= LogManager._();

  static final StreamController<String> _logStreamController =
      StreamController<String>.broadcast();

  static IOSink? _logSink;
  static File? _currentLogFile;
  static final _writeQueue = <String>[];
  static bool _isWriting = false;
  static Timer? _rotationTimer;
  static DateTime? _lastRotationCheck;

  /// Инициализация логгера
  static Future<void> initialize() async {
    await _ensureLogDirectory();
    await _setupCurrentLogFile();
    _setupRotationTimer();
    _startLogWriter();
  }

  /// Создает директорию для логов если её нет
  static Future<Directory> _ensureLogDirectory() async {
    final basePath = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOWNLOAD);
    final logDir = Directory(p.join(basePath, AppConfig.logsDirName));

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  /// Настраивает текущий файл лога
  static Future<void> _setupCurrentLogFile() async {
    final logDir = await _ensureLogDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final fileName = 'app_log_$timestamp${AppConfig.logFileExtension}';

    _currentLogFile = File(p.join(logDir.path, fileName));
    _logSink = _currentLogFile!.openWrite(mode: FileMode.append);

    // Записываем заголовок сессии
    await _writeToFile(_formatLogEntry(
      LogLevel.warning,
      'ПРИЛОЖЕНИЕ',
      'Начата сессия логирования - ${AppConfig.appName}',
    ));
  }

  /// Настраивает таймер для проверки ротации логов
  static void _setupRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(
      AppConfig.logRotationCheckInterval,
      (_) => _checkLogRotation(),
    );
  }

  /// Запускает асинхронный писатель логов
  static void _startLogWriter() {
    Timer.periodic(const Duration(milliseconds: 100), (_) {
      _processWriteQueue();
    });
  }

  /// Обрабатывает очередь записи логов
  static Future<void> _processWriteQueue() async {
    if (_isWriting || _writeQueue.isEmpty || _logSink == null) return;

    _isWriting = true;
    try {
      final batch = List<String>.from(_writeQueue);
      _writeQueue.clear();

      for (final logEntry in batch) {
        await _writeToFile(logEntry);
      }
      await _logSink!.flush();
    } catch (e) {
      // В случае ошибки возвращаем записи обратно в очередь
      _writeQueue.insertAll(0, _writeQueue);
    } finally {
      _isWriting = false;
    }
  }

  /// Записывает строку в файл
  static Future<void> _writeToFile(String logEntry) async {
    try {
      _logSink?.writeln(logEntry);
      _logStreamController.add(logEntry);
    } catch (e) {
      // Fallback - выводим в консоль при ошибке записи в файл
      print('[ОШИБКА_ЛОГОВ] Не удалось записать лог: $e');
      print('[РЕЗЕРВ_ЛОГОВ] $logEntry');
    }
  }

  /// Проверяет необходимость ротации логов
  static Future<void> _checkLogRotation() async {
    if (_currentLogFile == null) return;

    try {
      final fileSize = await _currentLogFile!.length();
      final now = DateTime.now();

      // Проверяем размер файла
      if (fileSize >= AppConfig.maxLogFileSize) {
        await _rotateLog('Достигнут максимальный размер файла');
        return;
      }

      // Проверяем возраст файла (ротация каждый день)
      if (_lastRotationCheck != null) {
        final daysSinceLastCheck = now.difference(_lastRotationCheck!).inDays;
        if (daysSinceLastCheck >= 1) {
          await _rotateLog('Ежедневная ротация');
          return;
        }
      }

      _lastRotationCheck = now;

      // Удаляем старые файлы
      await _cleanupOldLogs();
    } catch (e) {
      await _addToQueue(_formatLogEntry(
        LogLevel.error,
        'ЛОГГЕР',
        'Ошибка проверки ротации логов: $e',
      ));
    }
  }

  /// Ротирует текущий лог-файл
  static Future<void> _rotateLog(String reason) async {
    try {
      await _writeToFile(_formatLogEntry(
        LogLevel.warning,
        'ЛОГГЕР',
        'Ротация файла логов: $reason',
      ));

      await _logSink?.close();
      await _setupCurrentLogFile();

      await _writeToFile(_formatLogEntry(
        LogLevel.warning,
        'ЛОГГЕР',
        'Файл логов успешно ротирован',
      ));
    } catch (e) {
      print('[ОШИБКА_ЛОГОВ] Не удалось ротировать лог: $e');
    }
  }

  static Future<void> _cleanupOldLogs() async {
    try {
      final logDir = await _ensureLogDirectory();
      final logFiles = await logDir
          .list()
          .where((entity) =>
              entity is File &&
              entity.path.endsWith(AppConfig.logFileExtension))
          .cast<File>()
          .toList();

      // Сортируем по времени модификации (старые сначала)
      logFiles
          .sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      final now = DateTime.now();

      // Удаляем файлы старше максимального возраста
      for (final file in logFiles) {
        final age = now.difference(file.lastModifiedSync());
        if (age > AppConfig.maxLogAge) {
          await file.delete();
          continue;
        }
        break; // Остальные файлы новее
      }

      // Удаляем лишние файлы (если их больше максимального количества)
      final remainingFiles = await logDir
          .list()
          .where((entity) =>
              entity is File &&
              entity.path.endsWith(AppConfig.logFileExtension))
          .cast<File>()
          .toList();

      if (remainingFiles.length > AppConfig.maxLogFilesCount) {
        remainingFiles.sort(
            (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

        final filesToDelete = remainingFiles
            .take(remainingFiles.length - AppConfig.maxLogFilesCount);

        for (final file in filesToDelete) {
          await file.delete();
        }
      }
    } catch (e) {
      print('[ОШИБКА_ЛОГОВ] Не удалось очистить старые логи: $e');
    }
  }

  /// Форматирует запись лога
  static String _formatLogEntry(
      LogLevel level, String component, String message) {
    final timestamp =
        DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final formattedLevel = level.displayName.padRight(7);
    final formattedComponent = component.padRight(15);

    return '[$timestamp] [$formattedLevel] [$formattedComponent] $message';
  }

  // Убрали проверки уровней - логируем только важные события

  /// Добавляет запись в очередь на запись
  static Future<void> _addToQueue(String logEntry) async {
    _writeQueue.add(logEntry);

    // Ограничиваем размер очереди
    if (_writeQueue.length > 500) {
      _writeQueue.removeRange(0, 50); // Удаляем старые записи
    }
  }



  /// Логирует предупреждение
  static Future<void> warning(String component, String message) async {
    await _addToQueue(_formatLogEntry(LogLevel.warning, component, message));
  }

  /// Логирует ошибку
  static Future<void> error(String component, String message,
      [Object? error, StackTrace? stackTrace]) async {
    final fullMessage = error != null ? '$message | Ошибка: $error' : message;

    await _addToQueue(_formatLogEntry(LogLevel.error, component, fullMessage));

    if (stackTrace != null) {
      await _addToQueue(_formatLogEntry(
        LogLevel.error,
        component,
        'Стек вызовов: ${stackTrace.toString()}',
      ));
    }
  }

  static Future<void> debug(String component, String message) async {
    // Не логируем отладочную информацию
  }

  static Future<void> info(String component, String message) async {
    // Не логируем информационные сообщения
  }

  static Future<void> bluetooth(String operation, String message,
      [LogLevel level = LogLevel.error]) async {
    if (level == LogLevel.error || level == LogLevel.warning) {
      await _addToQueue(
          _formatLogEntry(level, 'BLUETOOTH', '$operation: $message'));
    }
  }

  static Future<void> database(String operation, String message,
      [LogLevel level = LogLevel.error]) async {
    if (level == LogLevel.error || level == LogLevel.warning) {
      await _addToQueue(_formatLogEntry(level, 'БД', '$operation: $message'));
    }
  }

  static Future<void> web(String operation, String message,
      [LogLevel level = LogLevel.error]) async {
    if (level == LogLevel.error || level == LogLevel.warning) {
      await _addToQueue(_formatLogEntry(level, 'ВЕБ', '$operation: $message'));
    }
  }

  static Future<void> permissions(String permission, String message,
      [LogLevel level = LogLevel.error]) async {
    if (level == LogLevel.error || level == LogLevel.warning) {
      await _addToQueue(
          _formatLogEntry(level, 'РАЗРЕШЕНИЯ', '$permission: $message'));
    }
  }

  static Future<void> fileOperation(String operation, String message,
      [LogLevel level = LogLevel.error]) async {
    if (level == LogLevel.error || level == LogLevel.warning) {
      await _addToQueue(
          _formatLogEntry(level, 'ФАЙЛЫ', '$operation: $message'));
    }
  }

  static Stream<String> get logStream => _logStreamController.stream;

  static Future<List<File>> getAllLogFiles() async {
    try {
      final logDir = await _ensureLogDirectory();
      final logFiles = await logDir
          .list()
          .where((entity) =>
              entity is File &&
              entity.path.endsWith(AppConfig.logFileExtension))
          .cast<File>()
          .toList();

      logFiles
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return logFiles;
    } catch (e) {
      return [];
    }
  }

  static Future<String> getAllLogsContent() async {
    try {
      final logFiles = await getAllLogFiles();
      final logContent = StringBuffer();

      for (final file in logFiles) {
        try {
          final content = await file.readAsString();
          logContent.writeln('=== ${p.basename(file.path)} ===');
          logContent.writeln(content);
          logContent.writeln('');
        } catch (e) {
          logContent.writeln('Ошибка чтения файла ${file.path}: $e');
          logContent.writeln('');
        }
      }

      return logContent.toString();
    } catch (e) {
      await error('ЛОГГЕР', 'Не удалось получить содержимое логов', e);
      return 'Ошибка получения логов: $e';
    }
  }

  /// Очищает все лог-файлы
  static Future<void> clearAllLogs() async {
    try {
      final logFiles = await getAllLogFiles();
      for (final file in logFiles) {
        await file.delete();
      }

      await _setupCurrentLogFile();
      await warning('ЛОГГЕР', 'Все файлы логов очищены');
    } catch (e) {
      await error('ЛОГГЕР', 'Не удалось очистить логи', e);
    }
  }

  static Future<void> dispose() async {
    _rotationTimer?.cancel();
    await _logSink?.close();
    await _logStreamController.close();
  }
}
