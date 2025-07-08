import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../common/config.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';

class ArchiveSyncManager {
  ArchiveSyncManager._();

  static Future<Directory> getArchivesDirectory() async {
    String basePath = "/storage/emulated/0/Download";
    final archiveDir = Directory(p.join(basePath, AppConfig.archivesDirName));
    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }
    return archiveDir;
  }
  static Future<List<String>> getPending() async {
    final archiveDir = await getArchivesDirectory();
    if (!await archiveDir.exists()) {
      print('[ArchiveSyncManager] getPending: archiveDir не найден');
      return [];
    }
    final files = await archiveDir.list().toList();
    final pending = files
        .where((f) =>
            f is File &&
            f.path
                .endsWith(AppConfig.notExportedSuffix + AppConfig.dbExtension))
        .map((f) => f.path)
        .toList();
    return pending;
  }

  static Future<void> addPending(String path) async {
    await getPending();
  }

  static Future<void> markExported(String pendingPath) async {
    if (!pendingPath
        .endsWith(AppConfig.notExportedSuffix + AppConfig.dbExtension)) {
      return;
    }
    final exportedPath = pendingPath.replaceAll(
        AppConfig.notExportedSuffix + AppConfig.dbExtension,
        AppConfig.dbExtension);
    final file = File(pendingPath);
    if (await file.exists()) {
      await file.rename(exportedPath);
      print('[ArchiveSyncManager] markExported: renamed to $exportedPath');
    } else {
      print('[ArchiveSyncManager] markExported: file does not exist');
    }
  }

  static String getDisplayName(String path) {
    final file = p
        .basename(path)
        .replaceAll(AppConfig.notExportedSuffix + AppConfig.dbExtension, '')
        .replaceAll(AppConfig.dbExtension, '');
    final match = RegExp(r'^([^_]+)_(.+)$').firstMatch(file);
    final display = match != null ? match.group(1)! : file;
    print('[ArchiveSyncManager] getDisplayName: path=$path display=$display');
    return display;
  }
}

class ExportStatusManager {
  static Future<File> _getStatusFile() async {
    final downloadsDir = await getDownloadsDirectory();
    final archiveDir =
        Directory(p.join(downloadsDir!.path, AppConfig.archivesDirName));
    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }
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

  static Future<Map<String, dynamic>?> getArchiveStatus(String fileName) async {
    final data = await _readStatus();
    return data[fileName] as Map<String, dynamic>?;
  }

  static Future<void> setArchiveStatus(
      String fileName, String status, List<int> exportedOps) async {
    final data = await _readStatus();
    data[fileName] = {
      'status': status,
      'exported_ops': exportedOps,
    };
    await _writeStatus(data);
  }

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
