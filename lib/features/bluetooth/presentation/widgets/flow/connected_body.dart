import 'package:bluetooth_per/common/config.dart';
import 'package:bluetooth_per/common/widgets/base_card.dart';
import 'package:bluetooth_per/common/widgets/progress_bar.dart';
import 'package:bluetooth_per/features/bluetooth/presentation/bloc/transfer_cubit.dart';
import 'package:bluetooth_per/features/bluetooth/presentation/bloc/transfer_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'connected_device_card.dart';

class ConnectedBody extends StatelessWidget {
  final ConnectedState state;
  const ConnectedBody({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransferCubit>();
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConnectedDeviceCard(
          name: state.connectedDevice.name.replaceAll("Quantor", ""),
          macAddress: state.connectedDevice.macAddress,
        ),
        const SizedBox(height: AppConfig.spacingLarge),
        const Text(
          'Архив',
          style: AppConfig.screenTitleStyle,
        ),
        const SizedBox(height: AppConfig.spacingMedium),
        ...state.archives.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: AppConfig.spacingSmall),
            child: BaseCard(
              onTap: () => cubit.downloadArchive(a),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProgressBarWithPercent(progress: 0.0),
                  SizedBox(height: AppConfig.spacingMedium),
                  Text(
                    'Размер: -',
                    style: AppConfig.bodySecondaryTextStyle,
                  ),
                  Text(
                    'Время загрузки: -',
                    style: AppConfig.bodySecondaryTextStyle,
                  ),
                  Text(
                    'Скорость: ',
                    style: AppConfig.bodySecondaryTextStyle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
