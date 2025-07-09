import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_sizes.dart';
import '../config/app_theme.dart';

/// Base widget for displaying status messages with optional icon and loading state
class BaseStatusWidget extends StatelessWidget {
  final String message;
  final IconData? icon;
  final Color? iconColor;
  final bool showLoading;
  final double? iconSize;
  final TextStyle? textStyle;
  final Widget? additionalContent;

  const BaseStatusWidget({
    super.key,
    required this.message,
    this.icon,
    this.iconColor,
    this.showLoading = false,
    this.iconSize,
    this.textStyle,
    this.additionalContent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showLoading)
            const SizedBox(
              width: AppSizes.progressBarLoadingSize,
              height: AppSizes.progressBarLoadingSize,
              child: CircularProgressIndicator(strokeWidth: AppSizes.progressBarStrokeWidth),
            )
          else if (icon != null)
            Icon(
              icon,
              color: iconColor ?? AppColors.primary,
              size: iconSize ?? AppSizes.iconXLarge,
            ),
          if (icon != null || showLoading) const SizedBox(height: AppSizes.spacingXLarge),
          Text(
            message,
            style: textStyle ?? AppTheme.titleStyle,
            textAlign: TextAlign.center,
          ),
          if (additionalContent != null) ...[
            const SizedBox(height: AppSizes.spacingMedium),
            additionalContent!,
          ],
        ],
      ),
    );
  }
}

/// Specific status widgets for common use cases

class BluetoothDisabledWidget extends StatelessWidget {
  final String title;
  final String description;

  const BluetoothDisabledWidget({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return BaseStatusWidget(
      message: title,
      icon: Icons.bluetooth_disabled,
      iconColor: AppColors.info,
      additionalContent: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingHorizontal),
        child: Text(
          description,
          style: AppTheme.bodyStyle.copyWith(color: AppColors.textTertiary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class ErrorStatusWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const ErrorStatusWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return BaseStatusWidget(
      message: message,
      icon: Icons.error_outline,
      iconColor: AppColors.error,
      textStyle: AppTheme.titleStyle.copyWith(color: AppColors.error),
      additionalContent: onRetry != null
          ? ElevatedButton(
              onPressed: onRetry,
              child: Text(retryLabel ?? 'Попробовать снова'),
            )
          : null,
    );
  }
}

class LoadingStatusWidget extends StatelessWidget {
  final String message;

  const LoadingStatusWidget({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return BaseStatusWidget(
      message: message,
      showLoading: true,
    );
  }
}