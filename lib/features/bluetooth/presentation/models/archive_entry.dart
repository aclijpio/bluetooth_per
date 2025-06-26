import 'package:equatable/equatable.dart';

class ArchiveEntry extends Equatable {
  final String fileName;
  final int sizeBytes;

  const ArchiveEntry({required this.fileName, required this.sizeBytes});

  @override
  List<Object?> get props => [fileName, sizeBytes];
}
