import 'package:flutter/material.dart';

class ProgressBarWithPercent extends StatelessWidget {
  final double progress; // 0..1
  const ProgressBarWithPercent({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              color: const Color(0xFF2E6FED),
              backgroundColor: const Color(0xFFC0D5F2),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 70, // enough to fit "100.0%" without changing layout
          child: Text(
            '${(progress * 100).toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF547FE7),
            ),
          ),
        ),
      ],
    );
  }
}
