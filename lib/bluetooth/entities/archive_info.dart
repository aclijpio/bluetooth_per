import 'package:equatable/equatable.dart';

/// Информация об архиве
class ArchiveInfo extends Equatable {
  final String path;
  final String fileName;
  final DateTime? createdAt;
  final int? fileSize;

  const ArchiveInfo({
    required this.path,
    required this.fileName,
    this.createdAt,
    this.fileSize,
  });

  /// Извлекает имя файла из пути
  static String extractFileName(String path) {
    final parts = path.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }

  /// Создает ArchiveInfo из пути
  factory ArchiveInfo.fromPath(String path) {
    return ArchiveInfo(
      path: path,
      fileName: extractFileName(path),
    );
  }

  @override
  List<Object?> get props => [path, fileName, createdAt, fileSize];

  @override
  String toString() =>
      'ArchiveInfo(path: $path, fileName: $fileName, fileSize: $fileSize)';
}
