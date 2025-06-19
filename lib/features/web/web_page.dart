import 'dart:convert';

import 'package:bluetooth_per/features/web/presentation/bloc/operations_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/sending_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/widgets/device_info_widget.dart';
import 'package:bluetooth_per/features/web/presentation/widgets/file_path_widget.dart';
import 'package:bluetooth_per/features/web/presentation/widgets/operations_list_widget.dart';
import 'package:bluetooth_per/features/web/presentation/widgets/send_button_widget.dart';
import 'package:bluetooth_per/features/web/presentation/widgets/sending_progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WebPage extends StatelessWidget {
  const WebPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Экспорт данных Quantor'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const FilePathWidget(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        context.read<OperationsCubit>().clearOperations();
                        context.read<SendingCubit>().resetSendingState();
                        context.read<OperationsCubit>().getOperations();
                      },
                      child: const Text('Запросить'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        context.read<OperationsCubit>().clearOperations();
                        context.read<SendingCubit>().resetSendingState();
                      },
                      child: const Text('Очистить'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const DeviceInfoWidget(),
              const SizedBox(height: 8),
              const Expanded(child: OperationsListWidget()),
              const SizedBox(height: 8),
              const SendButtonWidget(),
              const SizedBox(height: 8),
              const SendingProgressWidget(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
