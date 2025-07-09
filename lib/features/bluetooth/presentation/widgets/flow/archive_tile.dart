import 'package:bluetooth_per/core/config.dart';
import 'package:bluetooth_per/core/widgets/base_card.dart';
import 'package:flutter/material.dart';

class ArchiveTile extends StatelessWidget {
  final String name;
  final String date;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const ArchiveTile({
    super.key,
    required this.name,
    required this.date,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: onLongPress,
      child: BaseCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined,
                color: AppConfig.primaryColor, size: 28),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppConfig.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppConfig.tertiaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: AppConfig.primaryColor),
          ],
        ),
      ),
    );
  }
}
