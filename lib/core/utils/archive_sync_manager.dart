import 'dart:io';

import 'package:external_path/external_path.dart';
import 'package:path/path.dart' as p;

import '../config.dart';
import 'export_status_manager.dart';

class ArchiveSyncManager {
  ArchiveSyncManager._();

  static Future<Directory> getArchivesDirectory() async {
    final basePath = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOWNLOAD);
    final archiveDir = Directory(p.join(basePath, AppConfig.archivesDirName));
    print(archiveDir);
    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }
    return archiveDir;
  }

  static Future<List<String>> getPending() async {
    final archiveDir = await getArchivesDirectory();
    if (!await archiveDir.exists()) {
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
    if (path.endsWith(AppConfig.notExportedSuffix + AppConfig.dbExtension)) {
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      final newPath = path.replaceFirst(RegExp(r'\.db$'),
          '${AppConfig.notExportedSuffix}${AppConfig.dbExtension}');
      try {
        await file.rename(newPath);
      } catch (_) {
        // Игнорируем ошибки, например, если файл уже существует
      }
    }
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
    }
  }

  static String getDisplayName(String path) {
    final file = p
        .basename(path)
        .replaceAll(AppConfig.notExportedSuffix + AppConfig.dbExtension, '')
        .replaceAll(AppConfig.dbExtension, '');
    final match = RegExp(r'^([^_]+)_(.+)$').firstMatch(file);
    return match != null ? match.group(1)! : file;
  }

  // Удаляет архив из списка ожидающих (удаляет файл)
  static Future<void> deletePending(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      // Также удаляем статус экспорта из ExportStatusManager
      final fileName = p.basename(path);
      await ExportStatusManager.removeArchiveStatus(fileName);
    }
  }
}
