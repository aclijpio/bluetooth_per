import 'dart:io';
import 'package:bluetooth_per/features/web/data/repositories/main_data.dart';
import 'package:bluetooth_per/features/web/utils/server_connection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

class FilePathWidget extends StatefulWidget {
  const FilePathWidget({
    super.key,
  });

  @override
  State<FilePathWidget> createState() => _FilePathWidgetState();
}

class _FilePathWidgetState extends State<FilePathWidget> {
  bool _isDownloading = false;

  Future<void> _downloadDbFromServer() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final response = await ServerConnection.getReq('get_db_file');

      if (response is int) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading file: $response')),
        );
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/quantor_data.db');
      await file.writeAsBytes(response);

      setState(() {
        context.read<MainData>().dbPath = file.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database file downloaded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbPath = context.read<MainData>().dbPath;
    final hasFile = dbPath.isNotEmpty;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Путь к файлу: '),
            Expanded(
              child: Text(
                dbPath,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (hasFile)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    context.read<MainData>().dbPath = '';
                    context.read<MainData>().resetOperationData();
                  });
                },
                tooltip: 'Очистить путь к файлу',
              ),
            ElevatedButton(
              onPressed: () async {
                try {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles();
                  if (result != null) {
                    PlatformFile file = result.files.first;
                    if (file.path != null) {
                      setState(() {
                        context.read<MainData>().dbPath = file.path!;
                        context.read<MainData>().resetOperationData();
                      });
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error selecting file: $e')),
                  );
                }
              },
              child: const Text('Выбрать файл'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _isDownloading ? null : _downloadDbFromServer,
          child: _isDownloading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Загрузить с сервера'),
        ),
      ],
    );
  }
}
