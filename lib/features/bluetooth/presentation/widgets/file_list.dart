import 'package:bluetooth_per/features/bluetooth/presentation/widgets/file_download_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';

class FileList extends StatelessWidget {
  const FileList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        if (state is BluetoothConnected) {
          return ListView.builder(
            itemCount: state.fileList.length,
            itemBuilder: (context, index) {
              final fileName = state.fileList[index];
              return Column(
                children: [
                  ListTile(
                    title: Text(fileName),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => context.read<BluetoothBloc>().add(
                        DownloadFile(fileName),
                      ),
                    ),
                  ),
                  FileDownloadProgressBar(fileName: fileName)
                ],
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
