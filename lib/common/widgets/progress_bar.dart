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
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0B78CC)),
        ),
        const SizedBox(height: 8),
        Text(
          text ?? '${(progress * 100).toInt()}%',
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
