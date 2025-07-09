import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../common/config.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'export_status_manager.dart';

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
    // Этот метод теперь не нужен, так как файл уже создается с суффиксом NEED_EXPORT
    // при загрузке в BluetoothRepositoryImpl
    print('[ArchiveSyncManager] addPending called for: $path');
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

  // Удаляет архив из списка ожидающих (удаляет файл)
  static Future<void> deletePending(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      print('[ArchiveSyncManager] deletePending: deleted file at $path');

      // Также удаляем статус экспорта из ExportStatusManager
      final fileName = p.basename(path);
      await ExportStatusManager.removeArchiveStatus(fileName);
    } else {
      print('[ArchiveSyncManager] deletePending: file not found at $path');
    }
  }
}
