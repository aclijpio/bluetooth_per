import 'package:flutter/material.dart';

class ProgressWidget extends StatelessWidget {
  final double progress;
  final String? title;
  final String? subtitle;
  final bool showPercentage;
  final Color? progressColor;
  final Color? backgroundColor;

  const ProgressWidget({
    super.key,
    required this.progress,
    this.title,
    this.subtitle,
    this.showPercentage = true,
    this.progressColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: backgroundColor ?? Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 8,
                width: MediaQuery.of(context).size.width *
                    progress.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: progressColor ?? const Color(0xFF0B78CC),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          if (showPercentage) ...[
            const SizedBox(height: 12),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: progressColor ?? const Color(0xFF0B78CC),
              ),
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class CircularProgressWidget extends StatelessWidget {
  final double progress;
  final String? text;
  final double size;
  final Color? progressColor;
  final Color? backgroundColor;

  const CircularProgressWidget({
    super.key,
    required this.progress,
    this.text,
    this.size = 80,
    this.progressColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 6,
                backgroundColor: backgroundColor ?? Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  progressColor ?? const Color(0xFF0B78CC),
                ),
              ),
              Center(
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: size * 0.15,
                    fontWeight: FontWeight.w600,
                    color: progressColor ?? const Color(0xFF0B78CC),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (text != null) ...[
          const SizedBox(height: 16),
          Text(
            text!,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
