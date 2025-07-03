import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ArchiveSyncManager {
  ArchiveSyncManager._();

  static Future<List<String>> getPending() async {
    Directory downloadDir;
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        // Для пути вида "/storage/emulated/0/Android/data/..." берём часть до
        // "Android" и добавляем "Download/quan".
        final rootPath = extDir.path.split('Android').first;
        downloadDir = Directory(p.join(rootPath, 'Download', 'quan'));
      } else {
        // Fallback на стандартный путь
        downloadDir = Directory('/storage/emulated/0/Download/quan');
      }
    } catch (_) {
      downloadDir = Directory('/storage/emulated/0/Download/quan');
    }
    print('[ArchiveSyncManager] getPending: dir=${downloadDir.path}');
    if (!await downloadDir.exists()) {
      print('[ArchiveSyncManager] getPending: downloadDir does not exist');
      return [];
    }
    final files = await downloadDir.list().toList();
    final pending = files
        .where((f) => f is File && f.path.endsWith('.db.pending'))
        .map((f) => f.path)
        .toList();
    print(
        '[ArchiveSyncManager] getPending: found ${pending.length} pending files');
    return pending;
  }

  static Future<void> addPending(String path) async {
    print('[ArchiveSyncManager] addPending: $path');
    final list = await getPending();
    print(
        '[ArchiveSyncManager] addPending: updated pending list, total=${list.length}');
  }

  static Future<void> markExported(String pendingPath) async {
    print('[ArchiveSyncManager] markExported: $pendingPath');
    if (!pendingPath.endsWith('.pending')) {
      print('[ArchiveSyncManager] markExported: not a .pending file, skipping');
      return;
    }
    final exportedPath = pendingPath.replaceAll('.db.pending', '.db');
    final file = File(pendingPath);
    if (await file.exists()) {
      await file.rename(exportedPath);
      print('[ArchiveSyncManager] markExported: renamed to $exportedPath');
    } else {
      print('[ArchiveSyncManager] markExported: file does not exist');
    }
  }

  static Future<String> getDisplayNameWithStatus(String path) async {
    final file = p.basename(path).replaceAll('.pending', '');
    final match = RegExp(r'^([^_]+)_(.+)$').firstMatch(file);
    final display = match != null ? match.group(1)! : file;
    // Проверяем статус архива
    final fileName = p.basename(path).replaceAll('.pending', '');
    final status = await ExportStatusManager.getArchiveStatus(fileName);
    String suffix = '';
    if (status == null ||
        status['status'] == null ||
        status['status'] == 'pending' ||
        status['status'] == 'partial') {
      suffix = ' (не экспортирован)';
    } else if (status['status'] == 'exported') {
      suffix = ' (экспортирован)';
    }
    print(
        '[ArchiveSyncManager] getDisplayNameWithStatus: path=$path display=$display$suffix');
    return display + suffix;
  }
}

class ExportStatusManager {
  static Future<File> _getStatusFile() async {
    // Путь к папке с архивами (замените на ваш путь, если нужно)
    final dir = Directory('/storage/emulated/0/Download/quan');
    return File(p.join(dir.path, 'export_status.json'));
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
}
