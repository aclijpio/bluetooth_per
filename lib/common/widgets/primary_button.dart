import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/config/app_sizes.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.buttonWidth,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.buttonText,
          padding: const EdgeInsets.symmetric(vertical: AppSizes.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: AppSizes.fontXLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
