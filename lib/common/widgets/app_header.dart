import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/config/app_colors.dart';
import '../../core/config/app_constants.dart';
import '../../core/config/app_sizes.dart';
import '../../core/config/app_strings.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingXLarge,
        vertical: AppSizes.paddingSmall,
      ),
      decoration: const BoxDecoration(
        color: AppColors.appBarBackground,
      ),
      width: double.infinity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            AppConstants.appLogoPath,
            width: AppConstants.logoSize,
            height: AppConstants.logoSize,
            colorFilter: const ColorFilter.mode(AppColors.buttonText, BlendMode.srcIn),
          ),
          const SizedBox(width: AppSizes.spacingMedium),
          const Text(
            AppStrings.appName,
            style: TextStyle(
              color: AppColors.buttonText,
              fontSize: AppSizes.fontHeader,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class MainMenuButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isBlocked;
  const MainMenuButton({
    Key? key,
    required this.onPressed,
    required this.isBlocked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentGeometry.topLeft,
      child: TextButton.icon(
        onPressed: isBlocked ? null : onPressed,
        icon: const Icon(Icons.arrow_back),
        label: const Text(AppStrings.backToMainMenu),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: AppSizes.fontMedium,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
