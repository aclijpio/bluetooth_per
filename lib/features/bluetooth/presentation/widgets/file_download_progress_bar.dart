import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/file_download_info.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_state.dart';
import 'download_progress.dart';

class FileDownloadProgressBar extends StatelessWidget {
  final String fileName;
  const FileDownloadProgressBar({super.key, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BluetoothBloc, BluetoothState, FileDownloadInfo?>(
      selector: (state) {
        if (state is BluetoothConnected) {
          return state.downloadInfo[fileName];
        }
        return null;
      },
      builder: (context, downloadInfo) {
        if (downloadInfo == null) return const SizedBox.shrink();
        return DownloadProgress(downloadInfo: downloadInfo);
      },
    );
  }
}
