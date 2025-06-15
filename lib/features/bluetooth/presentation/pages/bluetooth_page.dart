import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth File Transfer'),
        actions: [
          BlocBuilder<BluetoothBloc, BluetoothState>(
            builder: (context, state) {
              if (state is BluetoothEnabled) {
                return IconButton(
                  icon: const Icon(Icons.bluetooth_searching),
                  onPressed: () => context.read<BluetoothBloc>().add(StartScanning()),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<BluetoothBloc, BluetoothState>(
        builder: (context, state) {
          return Column(
            children: [
              const StatusBar(),
              if (state is BluetoothDisabled)
                Center(
                  child: ElevatedButton(
                    onPressed: () => context.read<BluetoothBloc>().add(EnableBluetooth()),
                    child: const Text('Enable Bluetooth'),
                  ),
                )
              else if (state is BluetoothScanning)
                const DeviceList()
              else if (state is BluetoothConnected)
                const FileList()
              else if (state is BluetoothError)
                Center(
                  child: Text(
                    state.message,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      ),
    );
  }
} 