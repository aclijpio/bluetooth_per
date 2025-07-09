import 'dart:io';

import 'package:bluetooth_per/common/config.dart';
import 'package:bluetooth_per/core/utils/archive_sync_manager.dart';
import 'package:bluetooth_per/features/bluetooth/presentation/bloc/transfer_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'archive_tile.dart';

class PendingArchivesBody extends StatelessWidget {
  final List<String> paths;
  const PendingArchivesBody({super.key, required this.paths});

  Future<String> _getArchiveDate(String path) async {
    final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(path);
    if (dateMatch != null) {
      return dateMatch.group(1)!;
    }
    try {
      final file = File(path);
      final modified = await file.lastModified();
      return '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _showDeleteDialog(
      BuildContext context, String path, String displayName) async {
    final cubit = context.read<TransferCubit>();

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: AppConfig.dialogBorderRadius,
          ),
          title: const Text(
            'Удалить архив?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Вы действительно хотите удалить архив "$displayName" из списка неотправленных?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Это действие нельзя отменить.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppConfig.errorColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Отмена',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppConfig.errorColor,
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await cubit.deletePendingArchive(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayNames = {
      for (var p in paths) p: ArchiveSyncManager.getDisplayName(p)
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Неотправленные архивы',
          style: AppConfig.screenTitleStyle,
        ),
        const SizedBox(height: AppConfig.spacingExtraSmall),
        const Text(
          'Удерживайте архив для удаления',
          style: TextStyle(
            color: AppConfig.tertiaryTextColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppConfig.spacingMedium),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                ...paths.map(
                  (p) => FutureBuilder<String>(
                    future: _getArchiveDate(p),
                    builder: (context, snapshot) {
                      final fileName = displayNames[p]!;
                      final dateStr = snapshot.data ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppConfig.spacingSmall),
                        child: ArchiveTile(
                          name: fileName,
                          date: dateStr,
                          onTap: () {
                            final cubit = context.read<TransferCubit>();
                            cubit.loadLocalArchive(p);
                          },
                          onLongPress: () {
                            _showDeleteDialog(context, p, fileName);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
