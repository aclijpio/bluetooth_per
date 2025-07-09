import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'archive_sync_manager.dart';

class ExportStatusManager {
  static Future<File> _getStatusFile() async {
    final archiveDir = await ArchiveSyncManager.getArchivesDirectory();
    return File(p.join(archiveDir.path, 'export_status.json'));
  }

  static Future<Map<String, dynamic>> _readStatus() async {
    final file = await _getStatusFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    }
    return {};
  }

  static Future<void> _writeStatus(Map<String, dynamic> data) async {
    final file = await _getStatusFile();
    await file.writeAsString(jsonEncode(data), flush: true);
  }

  // Получить статус архива
  static Future<Map<String, dynamic>?> getArchiveStatus(String fileName) async {
    final data = await _readStatus();
    return data[fileName] as Map<String, dynamic>?;
  }

  // Обновить статус архива
  static Future<void> setArchiveStatus(
      String fileName, String status, List<int> exportedOps) async {
    final data = await _readStatus();
    data[fileName] = {
      'status': status,
      'exported_ops': exportedOps,
    };
    await _writeStatus(data);
  }

  // Добавить экспортированную операцию
  static Future<void> addExportedOp(String fileName, int opDt) async {
    final data = await _readStatus();
    final entry = data[fileName] as Map<String, dynamic>? ??
        {
          'status': 'pending',
          'exported_ops': [],
        };
    final ops = List<int>.from(entry['exported_ops'] ?? []);
    if (!ops.contains(opDt)) ops.add(opDt);
    entry['exported_ops'] = ops;
    // Обновляем статус
    entry['status'] = 'partial'; // или 'exported', если все
    data[fileName] = entry;
    await _writeStatus(data);
  }

  // Удалить статус архива
  static Future<void> removeArchiveStatus(String fileName) async {
    final data = await _readStatus();
    data.remove(fileName);
    await _writeStatus(data);
  }
}
