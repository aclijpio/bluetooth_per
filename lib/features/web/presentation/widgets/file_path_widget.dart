import 'dart:io';

import 'package:bluetooth_per/core/data/main_data.dart';
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Путь к файлу:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              dbPath.isEmpty ? 'Файл не выбран' : dbPath,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.any,
                );
                if (result != null && result.files.single.path != null) {
                  final path = result.files.single.path!;
                  if (path.toLowerCase().endsWith('.db')) {
                    setState(() {
                      context.read<MainData>().dbPath = path;
                      context.read<MainData>().resetOperationData();
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Выберите файл с расширением .db')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Выбрать файл'),
            ),
          ],
        ),
      ),
    );
  }
}
