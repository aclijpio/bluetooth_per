import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

/// Сервис для работы с архивами
class ArchiveService {
  /// Распаковывает архив в указанную папку
  static Future<String> extractArchive(
      Uint8List archiveData, String fileName) async {
    try {
      // Получаем папку Downloads
      final downloadsDir = await _getDownloadsDirectory();
      final quanDir = Directory('${downloadsDir.path}/quan');

      // Создаем папку quan если её нет
      if (!await quanDir.exists()) {
        await quanDir.create(recursive: true);
      }

      // Распаковываем архив
      final archive = ZipDecoder().decodeBytes(archiveData);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final outFile = File('${quanDir.path}/$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      return quanDir.path;
    } catch (e) {
      throw Exception('Failed to extract archive: $e');
    }
  }

  /// Получает папку Downloads
  static Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      // Для других платформ используем временную папку
      return await getTemporaryDirectory();
    }
  }

  /// Проверяет, является ли файл архивом
  static bool isArchiveFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['zip', 'rar', '7z', 'tar', 'gz'].contains(extension);
  }
}
