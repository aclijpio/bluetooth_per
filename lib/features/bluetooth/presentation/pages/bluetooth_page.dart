import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../web/web_page.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import '../widgets/device_list.dart';
import '../widgets/file_list.dart';
import '../widgets/status_bar.dart';

class BluetoothPage extends StatelessWidget {
  const BluetoothPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BluetoothBloc, BluetoothState>(
      listener: (context, state) {
        if (state is BluetoothError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is BluetoothNavigateToWebExport) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const WebPage(),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('Bluetooth'),
            actions: [
              if (state is BluetoothConnected)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    context.read<BluetoothBloc>().add(const GetFileList());
                  },
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                const StatusBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: state is BluetoothConnected
                      ? const FileList()
                      : const DeviceList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
