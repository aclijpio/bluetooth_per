import 'package:bluetooth_per/core/config.dart';
import 'package:flutter/material.dart';

class BaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BaseCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppConfig.largeBorderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
        decoration: BoxDecoration(
          color: AppConfig.cardBackgroundColor,
          borderRadius: AppConfig.largeBorderRadius,
        ),
        child: child,
      ),
    );
  }
}
