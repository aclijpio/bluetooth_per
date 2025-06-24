import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bluetooth/domain/entities/file_download_info.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../../web/data/repositories/main_data.dart';
import '../../../web/presentation/bloc/operations_cubit.dart';
import '../../../web/presentation/bloc/operations_state.dart';
import '../../../web/presentation/bloc/sending_cubit.dart';
import '../../../web/presentation/bloc/sending_state.dart';

class UnifiedActionButton extends StatelessWidget {
  const UnifiedActionButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Nested BlocBuilders allow us to react to changes from different blocs that
    // affect the button state.
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, btState) {
        return BlocBuilder<OperationsCubit, OperationsState>(
          builder: (context, operState) {
            return BlocBuilder<SendingCubit, SendingState>(
              builder: (context, sendState) {
                final mainData = context.read<MainData>();

                // Determine button parameters based on the current application state
                String text = 'Поиск устройств';
                Color? background; // null – default button colour
                bool enabled = true;
                VoidCallback? onPressed;
                bool showProgress = false;

                // Helper to set disabled state easily
                void disable(String label) {
                  text = label;
                  enabled = false;
                }

                // -------- BLUETOOTH PHASE --------
                if (btState is BluetoothLoading) {
                  disable('Поиск устройств');
                  showProgress = true;
                } else if (btState is BluetoothScanning) {
                  final quantorDevices = btState.devices
                      .where((d) =>
                          (d.name ?? '').toLowerCase().contains('quantor'))
                      .toList();

                  if (quantorDevices.isEmpty) {
                    text = 'Повторить поиск';
                    onPressed = () {
                      context.read<BluetoothBloc>().add(const StartScanning());
                    };
                  } else if (quantorDevices.length > 1) {
                    disable('Выберите устройство');
                  } else {
                    // Single device found, waiting for connection
                    disable('Подключение');
                    showProgress = true;
                  }
                } else if (btState is FileDownloading) {
                  // Explicit downloading state emitted by the bloc
                  text = 'Отменить';
                  background = Colors.red;
                  final fileNameToCancel = btState.fileName;
                  onPressed = () {
                    context
                        .read<BluetoothBloc>()
                        .add(CancelDownload(fileNameToCancel));
                  };
                } else if (btState is BluetoothConnected ||
                    btState is BluetoothNavigateToWebExport) {
                  // Connected to a device

                  // Для BluetoothNavigateToWebExport притворяемся, что файл скачан и можно работать с web
                  final isWebExport = btState is BluetoothNavigateToWebExport;
                  final fileList =
                      isWebExport ? <String>[] : (btState as dynamic).fileList;
                  final downloadInfo = isWebExport
                      ? <String, FileDownloadInfo>{}
                      : (btState as dynamic).downloadInfo;

                  if (!isWebExport && fileList.isEmpty) {
                    disable('Поиск архива');
                    showProgress = true;
                  } else {
                    FileDownloadInfo? downloadingEntry;
                    try {
                      downloadingEntry = downloadInfo.values
                          .firstWhere((d) => d.isDownloading);
                    } catch (_) {
                      downloadingEntry = null;
                    }

                    if (!isWebExport && downloadingEntry != null) {
                      text = 'Отменить';
                      background = Colors.red;
                      final fileNameToCancel = downloadingEntry.fileName;
                      onPressed = () {
                        context
                            .read<BluetoothBloc>()
                            .add(CancelDownload(fileNameToCancel));
                      };
                    } else {
                      FileDownloadInfo? completedEntry;
                      try {
                        completedEntry = downloadInfo.values
                            .firstWhere((d) => d.isCompleted);
                      } catch (_) {
                        completedEntry = null;
                      }

                      if (!isWebExport && completedEntry == null) {
                        // DOWNLOAD NOT STARTED / NOT FINISHED
                        if (fileList.length == 1) {
                          text = 'Скачать архив';
                          background = Colors.blue;
                          final fileName = fileList.first;
                          onPressed = () {
                            context
                                .read<BluetoothBloc>()
                                .add(DownloadFile(fileName));
                          };
                        } else {
                          disable('Выберите архив');
                        }
                      } else {
                        // -------- WEB PHASE --------
                        if (mainData.operations.isEmpty) {
                          if (mainData.dbPath.isNotEmpty) {
                            if (operState is LoadingOperationsState) {
                              text = 'Отменить';
                              background = Colors.red;
                              onPressed = () {
                                context
                                    .read<OperationsCubit>()
                                    .cancelGetOperations();
                              };
                              showProgress = true;
                            } else {
                              text = 'Запросить';
                              background = Colors.orange;
                              onPressed = () {
                                context
                                    .read<OperationsCubit>()
                                    .clearOperations();
                                context
                                    .read<SendingCubit>()
                                    .resetSendingState();
                                context.read<OperationsCubit>().getOperations();
                              };
                            }
                          }
                        } else {
                          final unsynced = mainData.operations
                              .where((op) => op.canSend)
                              .toList();
                          if (unsynced.isEmpty) {
                            text = 'Вернуться';
                            background = Colors.blue;
                            onPressed = () {
                              context.read<MainData>().dbPath = '';
                              context.read<MainData>().resetOperationData();
                              context.read<OperationsCubit>().clearOperations();
                              context.read<SendingCubit>().resetSendingState();
                              context
                                  .read<BluetoothBloc>()
                                  .add(const StartScanning());
                            };
                          } else {
                            final anySelected =
                                unsynced.any((op) => op.selected);
                            if (!anySelected) {
                              disable('Выберите скважины');
                            } else {
                              if (sendState is ProcessingSendingState) {
                                text = 'Остановить';
                                background = Colors.red;
                                onPressed = () {
                                  context.read<SendingCubit>().needBrakeFlag =
                                      true;
                                };
                                showProgress = true;
                              } else {
                                text = 'Отправить на сервер';
                                background = Colors.green;
                                onPressed = () {
                                  context
                                      .read<SendingCubit>()
                                      .sendOperationList(() {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        duration: Duration(seconds: 1),
                                        content:
                                            Text('Экспорт данных завершен'),
                                      ),
                                    );
                                  });
                                };
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                } else if (btState is BluetoothError) {
                  // In error state we let user retry scanning
                  text = 'Повторить поиск';
                  onPressed = () {
                    context.read<BluetoothBloc>().add(const StartScanning());
                  };
                } else {
                  // Initial / BluetoothDisabled / BluetoothEnabled etc.
                  onPressed = () {
                    context.read<BluetoothBloc>().add(const StartScanning());
                  };
                  if (btState is BluetoothDisabled) {
                    text = 'Bluetooth выключен';
                    enabled = false;
                  }
                }

                // Build final button widget
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: background,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    onPressed: enabled ? onPressed : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          text,
                          style: const TextStyle(fontSize: 18),
                        ),
                        if (showProgress) ...[
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
