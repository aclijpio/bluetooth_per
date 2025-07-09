import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_sizes.dart';

/// Base progress widget with consistent styling and optional labels
class BaseProgressWidget extends StatelessWidget {
  final double? progress;
  final String? label;
  final String? percentageText;
  final double height;
  final BorderRadius? borderRadius;
  final Color? progressColor;
  final Color? backgroundColor;
  final bool showPercentage;

  const BaseProgressWidget({
    super.key,
    this.progress,
    this.label,
    this.percentageText,
    this.height = AppSizes.progressBarHeight,
    this.borderRadius,
    this.progressColor,
    this.backgroundColor,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: AppSizes.fontMedium,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingXSmall),
        ],
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: borderRadius ?? BorderRadius.circular(AppSizes.borderRadiusSmall),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: height,
                  backgroundColor: backgroundColor ?? AppColors.progressBarBackground.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressColor ?? AppColors.primary,
                  ),
                ),
              ),
            ),
            if (showPercentage && progress != null) ...[
              const SizedBox(width: AppSizes.spacingSmall),
              SizedBox(
                width: AppSizes.containerWidth,
                child: Text(
                  percentageText ?? '${(progress! * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: AppSizes.fontSmall,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Specific progress widgets for different use cases

class DownloadProgressWidget extends StatelessWidget {
  final double progress;
  final String? speedLabel;
  final int? fileSize;
  final double? elapsedTime;

  const DownloadProgressWidget({
    super.key,
    required this.progress,
    this.speedLabel,
    this.fileSize,
    this.elapsedTime,
  });

  @override
  Widget build(BuildContext context) {
    String label = 'Загрузка';
    if (speedLabel != null) {
      label += ' • $speedLabel';
    }
    if (fileSize != null && elapsedTime != null) {
      label += ' • ${_formatFileSize(fileSize!)}';
    }

    return BaseProgressWidget(
      progress: progress,
      label: label,
      height: AppSizes.progressBarHeight,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class ExportProgressWidget extends StatelessWidget {
  final double progress;
  final bool isExporting;

  const ExportProgressWidget({
    super.key,
    required this.progress,
    required this.isExporting,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExporting) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSizes.spacingXSmall,
        left: AppSizes.spacingSmall,
        right: AppSizes.spacingSmall,
      ),
      child: BaseProgressWidget(
        progress: progress,
        height: AppSizes.progressBarMinHeight,
        progressColor: AppColors.primaryLight,
        backgroundColor: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        showPercentage: false,
      ),
    );
  }
}