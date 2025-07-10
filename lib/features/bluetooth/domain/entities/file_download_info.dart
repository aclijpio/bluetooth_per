import 'package:equatable/equatable.dart';

class FileDownloadInfo extends Equatable {
  final String fileName;
  final double progress;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? fileSize;
  final String? filePath;
  final bool isDownloading;
  final bool isCompleted;
  final String? error;
  final int bytesReceived;
  final DateTime? lastUpdateTime;

  const FileDownloadInfo({
    required this.fileName,
    this.progress = 0.0,
    this.startTime,
    this.endTime,
    this.fileSize,
    this.filePath,
    this.isDownloading = false,
    this.isCompleted = false,
    this.error,
    this.bytesReceived = 0,
    this.lastUpdateTime,
  });

  FileDownloadInfo copyWith({
    String? fileName,
    double? progress,
    DateTime? startTime,
    DateTime? endTime,
    int? fileSize,
    String? filePath,
    bool? isDownloading,
    bool? isCompleted,
    String? error,
    int? bytesReceived,
    DateTime? lastUpdateTime,
  }) {
    return FileDownloadInfo(
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      fileSize: fileSize ?? this.fileSize,
      filePath: filePath ?? this.filePath,
      isDownloading: isDownloading ?? this.isDownloading,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }

  String get downloadDuration {
    if (startTime == null || endTime == null) return 'N/A';
    final duration = endTime!.difference(startTime!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes min $seconds sec';
  }

  String get formattedFileSize {
    if (fileSize == null) return 'N/A';
    final mb = fileSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  double get bytesPerSecond {
    if (!isDownloading || startTime == null || lastUpdateTime == null)
      return 0.0;
    final duration = lastUpdateTime!.difference(startTime!).inSeconds;
    if (duration <= 0) return 0.0;
    return bytesReceived / duration;
  }

  String get formattedSpeed {
    final speed = bytesPerSecond;
    if (speed <= 0) return 'N/A';
    if (speed >= 1024 * 1024) {
      return '${(speed / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else if (speed >= 1024) {
      return '${(speed / 1024).toStringAsFixed(2)} KB/s';
    } else {
      return '${speed.toStringAsFixed(0)} B/s';
    }
  }

  @override
  List<Object?> get props => [
        fileName,
        progress,
        startTime,
        endTime,
        fileSize,
        filePath,
        isDownloading,
        isCompleted,
        error,
        bytesReceived,
        lastUpdateTime,
      ];
}
