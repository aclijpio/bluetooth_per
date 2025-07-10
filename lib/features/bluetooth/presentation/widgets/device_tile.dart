import 'package:bluetooth_per/core/config.dart';
import 'package:flutter/material.dart';

import '../models/device.dart';

class DeviceTile extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;
  const DeviceTile({super.key, required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppConfig.largeBorderRadius,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          color: AppConfig.cardBackgroundColor,
          borderRadius: AppConfig.largeBorderRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              device.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppConfig.primaryTextColor,
              ),
            ),
            const Icon(Icons.arrow_forward, color: AppConfig.primaryColor),
          ],
        ),
      ),
    );
  }
}
