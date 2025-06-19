import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/file_download_info.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import 'file_download_progress_bar.dart';

class DeviceList extends StatelessWidget {
  const DeviceList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      buildWhen: (previous, current) {
        if (previous is BluetoothConnected && current is BluetoothConnected) {
          return previous.downloadInfo != current.downloadInfo ||
              previous.fileList != current.fileList;
        }
        return true;
      },
      builder: (context, state) {
        print('Building DeviceList with state: ${state.runtimeType}');

        if (state is BluetoothLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is BluetoothError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${state.message}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      context.read<BluetoothBloc>().add(const StartScanning()),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        } else if (state is BluetoothScanning) {
          return ListView.builder(
            itemCount: state.devices.length,
            itemBuilder: (context, index) {
              final device = state.devices[index];
              return ListTile(
                title: Text(device.name ?? 'Unknown Device'),
                subtitle: Text(device.address),
                trailing: IconButton(
                  icon: const Icon(Icons.bluetooth_connected),
                  onPressed: () => context.read<BluetoothBloc>().add(
                        ConnectToDevice(device),
                      ),
                ),
              );
            },
          );
        } else if (state is BluetoothConnected) {
          print('Connected state: device=${state.device.name}, files=${state.fileList.length}, downloads=${state.downloadInfo.length}');
          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                            'Connected to: ${state.device.name ?? 'Unknown Device'}'),
                        subtitle: Text(state.device.address),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Get File List'),
                            onPressed: () {
                              print('Get file list button pressed');
                              context.read<BluetoothBloc>().add(GetFileList());
                            },
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.bluetooth_disabled),
                            label: const Text('Disconnect'),
                            onPressed: () {
                              print('Disconnect button pressed');
                              context
                                  .read<BluetoothBloc>()
                                  .add(DisconnectFromDevice(state.device));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (state.fileList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        final firstFile = state.fileList.first;
                        context
                            .read<BluetoothBloc>()
                            .add(DownloadFile(firstFile));
                      },
                      child: const Text('Скачать файл'),
                    ),
                  ),
                ),
              if (state.fileList.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                      'Нет доступных файлов. Press "Get File List" для обновления.'),
                ),
              if (state.fileList.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: state.fileList.length,
                    itemBuilder: (context, index) {
                      final fileName = state.fileList[index];
                      final downloadInfo = state.downloadInfo[fileName];
                      print(
                          'Building file item: $fileName, downloadInfo: ${downloadInfo?.progress}');
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(fileName),
                              trailing: _buildTrailingWidget(
                                context,
                                fileName,
                                downloadInfo,
                              ),
                            ),
                            FileDownloadProgressBar(fileName: fileName),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        } else if (state is BluetoothDisabled) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Bluetooth is disabled'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context
                      .read<BluetoothBloc>()
                      .add(const EnableBluetooth()),
                  child: const Text('Enable Bluetooth'),
                ),
              ],
            ),
          );
        } else if (state is BluetoothEnabled) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Bluetooth is enabled'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      context.read<BluetoothBloc>().add(const StartScanning()),
                  child: const Text('Start Scanning'),
                ),
              ],
            ),
          );
        }
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Select a device to connect'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    context.read<BluetoothBloc>().add(const StartScanning()),
                child: const Text('Start Scanning'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrailingWidget(
    BuildContext context,
    String fileName,
    FileDownloadInfo? downloadInfo,
  ) {
    if (downloadInfo == null) {
      return IconButton(
        icon: const Icon(Icons.download),
        onPressed: () => context.read<BluetoothBloc>().add(
              DownloadFile(fileName),
            ),
      );
    }

    if (downloadInfo.isDownloading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      );
    }

    if (downloadInfo.isCompleted) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.info_outline),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'info',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File Size: ${downloadInfo.formattedFileSize}'),
                Text('Download Time: ${downloadInfo.downloadDuration}'),
                if (downloadInfo.filePath != null)
                  Text('Location: ${downloadInfo.filePath}'),
              ],
            ),
          ),
        ],
      );
    }

    if (downloadInfo.error != null) {
      return IconButton(
        icon: const Icon(Icons.error_outline, color: Colors.red),
        onPressed: () => context.read<BluetoothBloc>().add(
              DownloadFile(fileName),
            ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.download),
      onPressed: () => context.read<BluetoothBloc>().add(
            DownloadFile(fileName),
          ),
    );
  }
}
