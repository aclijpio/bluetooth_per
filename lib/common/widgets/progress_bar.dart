import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/config/app_sizes.dart';

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
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              minHeight: 16,
              valueColor:
              const AlwaysStoppedAnimation<Color>(Color(0xFF0B78CC)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width:
          45,
          child: Text(
            text ?? '${(progress * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF424242),
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
