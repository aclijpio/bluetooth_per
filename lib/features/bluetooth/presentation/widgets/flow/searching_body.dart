import 'package:bluetooth_per/core/config.dart';
import 'package:flutter/material.dart';

class SearchingBody extends StatelessWidget {
  const SearchingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Поиск устройств',
          style: AppConfig.subtitleStyle,
        ),
        SizedBox(height: AppConfig.spacingMedium),
        SizedBox(width: 40, height: 40, child: CircularProgressIndicator()),
      ],
    );
  }
}
