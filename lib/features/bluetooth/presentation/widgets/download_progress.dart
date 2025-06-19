import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../../domain/entities/file_download_info.dart';

class DownloadProgress extends StatelessWidget {
  final FileDownloadInfo downloadInfo;

  const DownloadProgress({
    super.key,
    required this.downloadInfo,
  });

  @override
  Widget build(BuildContext context) {
    print(
        'Building DownloadProgress: progress=${downloadInfo.progress}, size=${downloadInfo.fileSize}');

    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: downloadInfo.progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      downloadInfo.error != null
                          ? Colors.red
                          : Theme.of(context).primaryColor,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(downloadInfo.progress * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (downloadInfo.isDownloading) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.cancel, size: 20),
                  onPressed: () => context.read<BluetoothBloc>().add(
                        CancelDownload(downloadInfo.fileName),
                      ),
                  tooltip: 'Отменить загрузку',
                ),
              ],
            ],
          ),
          if (downloadInfo.fileSize != null) ...[
            const SizedBox(height: 4),
            Text(
              'Size: ${downloadInfo.formattedFileSize}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (downloadInfo.isDownloading) ...[
            if (downloadInfo.startTime != null) ...[
              const SizedBox(height: 4),
              Text(
                'Time elapsed: ${_getElapsedTime(downloadInfo.startTime!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Speed: ${downloadInfo.formattedSpeed}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (downloadInfo.error != null) ...[
            const SizedBox(height: 4),
            Text(
              'Error: ${downloadInfo.error}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String _getElapsedTime(DateTime startTime) {
    final now = DateTime.now();
    final difference = now.difference(startTime);
    final minutes = difference.inMinutes;
    final seconds = difference.inSeconds % 60;
    return '$minutes min $seconds sec';
  }
}
