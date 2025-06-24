import 'dart:io';
import 'dart:typed_data';

typedef ProgressCallback = void Function(double progress, int? totalBytes);
typedef CompleteCallback = void Function(String filePath);

class FileDownloader {
  FileDownloader({required this.directory});

  final Directory directory;

  late final File _file;
  late final IOSink _sink;
  int _expectedSize = 0;
  int _received = 0;
  bool _started = false;

  /// Инициализируем загрузку, открываем файл.
  void start(String fileName, int expectedSize) {
    if (_started) throw StateError('Downloader already started');
    _started = true;
    _expectedSize = expectedSize;
    _file = File('${directory.path}/$fileName');
    _sink = _file.openWrite();
  }

  /// Записываем очередной блок данных.
  void addChunk(Uint8List chunk,
      {ProgressCallback? onProgress, CompleteCallback? onComplete}) {
    if (!_started) throw StateError('Call start() first');
    _sink.add(chunk);
    _received += chunk.length;

    onProgress?.call(_received / _expectedSize, _expectedSize);

    if (_received >= _expectedSize) {
      _finish(onComplete);
    }
  }

  /// Принудительное завершение без ожидания размера.
  Future<void> finish({CompleteCallback? onComplete}) async {
    await _finish(onComplete);
  }

  Future<void> _finish(CompleteCallback? onComplete) async {
    await _sink.flush();
    await _sink.close();

    String finalPath = _file.path;
    if (_file.path.toLowerCase().endsWith('.gz')) {
      try {
        final rawName =
            _file.path.replaceFirst(RegExp(r'\.gz$', caseSensitive: false), '');
        final rawFile = File(rawName);
        await _file
            .openRead()
            .transform(gzip.decoder)
            .pipe(rawFile.openWrite());
        finalPath = rawFile.path;
      } catch (e) {
        // игнорируем ошибку распаковки, оставляем .gz
      }
    }

    onComplete?.call(finalPath);
  }
}
