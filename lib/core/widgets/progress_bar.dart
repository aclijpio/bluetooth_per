import 'package:bluetooth_per/core/config.dart';
import 'package:flutter/material.dart';

class ProgressBarWithPercent extends StatelessWidget {
  final double progress;
  final String? text;

  const ProgressBarWithPercent({
    super.key,
    required this.progress,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: AppConfig.progressBarBorderRadius,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppConfig.progressBarBackgroundColor,
              minHeight: AppConfig.progressBarHeight,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppConfig.progressBarColor),
            ),
          ),
        ),
        const SizedBox(width: AppConfig.progressBarSpacing),
        SizedBox(
          width: AppConfig.progressBarPercentWidth,
          child: Text(
            text ?? '${(progress * 100).toInt()}%',
            style: AppConfig.progressBarTextStyle,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
