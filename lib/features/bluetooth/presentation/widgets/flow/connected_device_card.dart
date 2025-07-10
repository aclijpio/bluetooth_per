import 'package:bluetooth_per/core/config.dart';
import 'package:flutter/material.dart';

import '../../../../../core/widgets/base_card.dart';

class ConnectedDeviceCard extends StatelessWidget {
  final String name;
  final String macAddress;
  const ConnectedDeviceCard(
      {super.key, required this.name, required this.macAddress});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Подключен к: $name',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: AppConfig.primaryTextColor,
            ),
          ),
          /*const SizedBox(height: 8),
          Text(
            macAddress,
            style: const TextStyle(fontSize: 16, color: AppConfig.tertiaryTextColor),
          ),*/
        ],
      ),
    );
  }
}
