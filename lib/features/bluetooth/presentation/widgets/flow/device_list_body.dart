import 'package:bluetooth_per/core/config.dart';
import 'package:bluetooth_per/features/bluetooth/presentation/bloc/transfer_cubit.dart';
import 'package:bluetooth_per/features/bluetooth/presentation/models/device.dart';
import 'package:bluetooth_per/features/bluetooth/presentation/widgets/device_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeviceListBody extends StatelessWidget {
  final List<Device> devices;
  const DeviceListBody({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransferCubit>();

    if (devices.isEmpty) {
      return const Center(
        child: Text(
          'Устройства не обнаружены',
          style: AppConfig.subtitleStyle,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: devices.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppConfig.spacingSmall),
            itemBuilder: (_, index) {
              final device = devices[index];
              return DeviceTile(
                device: device,
                onTap: () => cubit.connectToDevice(device),
              );
            },
          ),
        ),
      ],
    );
  }
}
