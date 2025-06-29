import 'package:equatable/equatable.dart';

class ArchiveEntry extends Equatable {
  final String fileName;
  final String path;
  final int sizeBytes;
  final DateTime? createdAt;

  const ArchiveEntry({
    required this.fileName,
    required this.path,
    this.sizeBytes = 0,
    this.createdAt,
  });

  @override
  List<Object?> get props => [fileName, path, sizeBytes, createdAt];

  @override
  String toString() =>
      'ArchiveEntry(fileName: $fileName, path: $path, sizeBytes: $sizeBytes)';
}
