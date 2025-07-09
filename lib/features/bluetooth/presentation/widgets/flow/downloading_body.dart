import 'package:bluetooth_per/common/config.dart';
import 'package:bluetooth_per/common/widgets/base_card.dart';
import 'package:bluetooth_per/common/widgets/progress_bar.dart';
import 'package:bluetooth_per/core/utils/formatting.dart';
import 'package:bluetooth_per/features/bluetooth/presentation/bloc/transfer_state.dart';
import 'package:flutter/material.dart';

import 'connected_device_card.dart';

class DownloadingBody extends StatelessWidget {
  final DownloadingState state;
  const DownloadingBody({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConnectedDeviceCard(
          name: state.connectedDevice.name.replaceAll("Quantor", ""),
          macAddress: state.connectedDevice.macAddress,
        ),
        const SizedBox(height: AppConfig.spacingLarge),
        // Archive label
        const Text(
          'Архив',
          style: AppConfig.screenTitleStyle,
        ),
        const SizedBox(height: AppConfig.spacingMedium),
        BaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressBarWithPercent(progress: state.progress),
              const SizedBox(height: AppConfig.spacingMedium),
              Text(
                'Размер: '
                '${state.fileSize != null ? formatSize(state.fileSize!) : '-'}',
                style: AppConfig.bodySecondaryTextStyle,
              ),
              Text(
                'Время загрузки: '
                '${state.elapsedTime != null ? formatTime(state.elapsedTime!) : '-'}',
                style: AppConfig.bodySecondaryTextStyle,
              ),
              Text(
                'Скорость: ${state.speedLabel}',
                style: AppConfig.bodySecondaryTextStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
