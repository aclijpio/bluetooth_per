import 'package:bluetooth_per/core/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onSettingsPressed;

  const AppHeader({super.key, this.onSettingsPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: AppConfig.primaryColor,
      ),
      width: double.infinity,
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/images/logo.svg',
            width: 36,
            height: 36,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Transfer-QT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (onSettingsPressed != null)
            IconButton(
              onPressed: onSettingsPressed,
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 28,
              ),
              tooltip: 'Настройки',
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
      alignment: Alignment.topLeft,
      child: TextButton.icon(
        onPressed: isBlocked ? null : onPressed,
        icon: const Icon(Icons.arrow_back),
        label: const Text('В главное меню'),
        style: TextButton.styleFrom(
          foregroundColor: AppConfig.primaryColor,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
