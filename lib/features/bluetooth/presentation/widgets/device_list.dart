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
          return const SizedBox.shrink();
        } else if (state is BluetoothError) {
          return const SizedBox.shrink();
        } else if (state is BluetoothScanning) {
          final quantorDevices = state.devices
              .where((d) => (d.name ?? '').toLowerCase().contains('quantor'))
              .toList();

          if (quantorDevices.isEmpty) {
            return const SizedBox.shrink();
          }

          return ListView.builder(
            itemCount: quantorDevices.length,
            itemBuilder: (context, index) {
              final device = quantorDevices[index];
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
          print(
              'Connected state: device=${state.device.name}, files=${state.fileList.length}, downloads=${state.downloadInfo.length}');
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
                    ],
                  ),
                ),
              ),
              if (state.fileList.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
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
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTrailingWidget(
    BuildContext context,
    String fileName,
    FileDownloadInfo? downloadInfo,
  ) {
    if (downloadInfo == null) {
      return const SizedBox.shrink();
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
      return const SizedBox.shrink();
    }

    if (downloadInfo.error != null) {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }
}
