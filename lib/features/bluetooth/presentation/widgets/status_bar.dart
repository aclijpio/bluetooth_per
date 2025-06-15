import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_state.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        String status;
        Color color;

        if (state is BluetoothInitial) {
          status = 'Initializing...';
          color = Colors.grey;
        } else if (state is BluetoothLoading) {
          status = 'Loading...';
          color = Colors.blue;
        } else if (state is BluetoothEnabled) {
          status = 'Bluetooth Enabled';
          color = Colors.green;
        } else if (state is BluetoothDisabled) {
          status = 'Bluetooth Disabled';
          color = Colors.red;
        } else if (state is BluetoothScanning) {
          status = 'Scanning for devices...';
          color = Colors.blue;
        } else if (state is BluetoothConnected) {
          status = 'Connected to ${state.device.name ?? "Unknown Device"}';
          color = Colors.green;
        } else if (state is BluetoothDisconnected) {
          status = 'Disconnected';
          color = Colors.orange;
        } else if (state is BluetoothError) {
          status = state.message;
          color = Colors.red;
        } else if (state is FileDownloading) {
          status = 'Downloading ${state.fileName}...';
          color = Colors.blue;
        } else if (state is FileDownloaded) {
          status = 'Downloaded ${state.fileName}';
          color = Colors.green;
        } else {
          status = 'Unknown state';
          color = Colors.grey;
        }

        return Container(
          padding: const EdgeInsets.all(16.0),
          color: color.withOpacity(0.1),
          child: Row(
            children: [
              Icon(
                Icons.bluetooth,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(color: color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 