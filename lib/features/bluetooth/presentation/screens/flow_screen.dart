import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:io';

import 'package:bluetooth_per/common/config.dart';
import '../bloc/transfer_cubit.dart';
import '../bloc/transfer_state.dart';
import '../widgets/device_tile.dart';
import '../widgets/archive_table.dart';
import '../models/device.dart';
import 'package:bluetooth_per/core/data/main_data.dart';
import 'package:bluetooth_per/core/utils/archive_sync_manager.dart';
import '../models/archive_entry.dart';
import 'package:bluetooth_per/common/bloc/operation_sending_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/sending_state.dart';
import 'package:bluetooth_per/common/widgets/primary_button.dart';
import 'package:bluetooth_per/common/widgets/progress_bar.dart';
import '../bloc/export_progress_cubit.dart';
import 'package:bluetooth_per/common/widgets/app_header.dart';
import 'package:bluetooth_per/core/di/injection_container.dart' as di;
import '../widgets/flow/searching_body.dart';
import '../widgets/flow/device_list_body.dart';
import '../widgets/flow/connected_body.dart';
import '../widgets/flow/downloading_body.dart';
import '../widgets/flow/pending_archives_body.dart';
import '../widgets/flow/connected_device_card.dart';
import '../widgets/flow/info_message_body.dart';

class DeviceFlowScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExportProgressCubit>(
      create: (_) => ExportProgressCubit(),
      child: const DeviceFlowScreenBody(),
    );
  }
}

class DeviceFlowScreenBody extends StatefulWidget {
  const DeviceFlowScreenBody({super.key});

  @override
  State<DeviceFlowScreenBody> createState() => _DeviceFlowScreenBodyState();
}

class _DeviceFlowScreenBodyState extends State<DeviceFlowScreenBody> {
  bool _hasTableSelection = false;
  bool _exportDialogShown = false;
  String? _exportError;
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransferCubit, TransferState>(
      listener: (context, state) {
        if (_exportDialogShown &&
            (state is ExportSuccessState || state is TableViewState)) {
          Navigator.of(context, rootNavigator: true).maybePop();
          _exportDialogShown = false;
        }
        if (state is TableViewState && _exportError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_exportError!), backgroundColor: Colors.red),
          );
          _exportError = null;
        }
        if (state is ExportSuccessState) {
          Future.delayed(AppConfig.uiShortDelay, () {
            if (mounted) {
              context.read<ExportProgressCubit>().reset();
            }
          });
        }
      },
      child: BlocProvider<OperationSendingCubit>(
        create: (ctx) => di.sl<OperationSendingCubit>(),
        child: Scaffold(
          body: Padding(
            padding: AppConfig.screenPadding,
            child: BlocBuilder<TransferCubit, TransferState>(
              builder: (context, state) {
                final cubit = context.read<TransferCubit>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state is DeviceListState ||
                        state is ConnectedState ||
                        state is TableViewState ||
                        state is ExportProgressState ||
                        state is SearchingStateWithDevices ||
                        state is BluetoothDisabledState)
                      MainMenuButton(
                        onPressed: () {
                          context.read<TransferCubit>().reset();
                        },
                        isBlocked:
                            (state is TableViewState && state.isLoading) ||
                                state is ExportingState ||
                                state is UploadingState ||
                                state is RefreshingState ||
                                state is DownloadingState ||
                                state is SearchingStateWithDevices,
                      ),
                    if (/*state is SearchingState ||*/
                        state is DeviceListState ||
                            state is SearchingStateWithDevices)
                      const Text(
                        'Устройства',
                        style: AppConfig.titleStyle,
                      ),
                    const SizedBox(height: AppConfig.spacingMedium),
                    Expanded(child: _buildBody(context, state)),
                    const SizedBox(height: AppConfig.spacingMedium),
                    BlocBuilder<OperationSendingCubit, SendingState>(
                      builder: (context, sendState) {
                        if (sendState is ProcessingSendingState) {
                          return Column(
                            children: [
                              ProgressBarWithPercent(
                                progress: sendState.percent,
                              ),
                              const SizedBox(
                                  height: AppConfig.spacingExtraSmall),
                              ElevatedButton(
                                onPressed: () {
                                  context
                                      .read<OperationSendingCubit>()
                                      .needBrakeFlag = true;
                                },
                                child: const Text('Остановить'),
                              ),
                            ],
                          );
                        } else if (sendState is ErrorSendingState) {
                          return Text(
                              'Ошибка экспорта: код ${sendState.errorCode}',
                              style:
                                  const TextStyle(color: AppConfig.errorColor));
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                    // Bottom button (поиск, скачать и т.д.)
                    _buildBottomButton(state, cubit),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TransferState state) {
    if (state is InitialSearchState) {
      return const SizedBox.shrink();
    } else if (state is SearchingState) {
      return const SearchingBody();
    } else if (state is SearchingStateWithDevices) {
      return DeviceListBody(devices: state.devices);
    } else if (state is DeviceListState) {
      return DeviceListBody(devices: state.devices);
    } else if (state is ConnectedState) {
      return ConnectedBody(state: state);
    } else if (state is UploadingState) {
      return ConnectedDeviceCard(
        name: state.connectedDevice.name.replaceAll("Quantor", ""),
        macAddress: state.connectedDevice.macAddress,
      );
    } else if (state is RefreshingState) {
      return ConnectedDeviceCard(
        name: state.connectedDevice.name.replaceAll("Quantor", ""),
        macAddress: state.connectedDevice.macAddress,
      );
    } else if (state is DownloadingState) {
      return DownloadingBody(state: state);
    } else if (state is TableViewState || state is ExportingState) {
      final mainData = context.read<MainData>();
      final displayName = ArchiveSyncManager.getDisplayName(
          state is TableViewState
              ? state.entry.fileName
              : (state as ExportingState).entry.fileName);

      final operations =
          (state is TableViewState) ? state.operations : mainData.operations;
      final bool checkboxesEnabled = (state is TableViewState &&
          !(state).disabled &&
          !state.isLoading &&
          state.operations.isNotEmpty);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                ArchiveTable(
                  entry: ArchiveEntry(
                    fileName: displayName,
                    sizeBytes: state is TableViewState
                        ? state.entry.sizeBytes
                        : (state as ExportingState).entry.sizeBytes,
                  ),
                  operations: operations,
                  onSelectionChanged: (selected) {
                    setState(() {
                      _hasTableSelection = selected;
                    });
                  },
                  checkboxesEnabled: checkboxesEnabled,
                ),
                if (state is TableViewState) ...[
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(strokeWidth: 7),
                        ),
                      ),
                    )
                  else if (state.operations.isEmpty)
                    Container(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sync_disabled,
                              size: 64,
                              color: Colors.green.withOpacity(0.7),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Все операции уже синхронизированы',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppConfig.secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Нет данных для экспорта',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppConfig.tertiaryTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      );
    } else if (state is PendingArchivesState) {
      return PendingArchivesBody(paths: state.dbPaths);
    } else if (state is ExportSuccessState) {
      return const SizedBox.shrink();
    } else if (state is NetErrorState) {
      final mainData = context.read<MainData>();
      final displayName = ArchiveSyncManager.getDisplayName(state.dbPath);
      final operations = mainData.operations;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                ArchiveTable(
                  entry: ArchiveEntry(
                    fileName: displayName,
                    sizeBytes: 0,
                  ),
                  operations: operations,
                  onSelectionChanged: (selected) {
                    setState(() {
                      _hasTableSelection = selected;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      );
    } else if (state is DbErrorState) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppConfig.errorColor, size: 48),
            const SizedBox(height: 16),
            Text(
              state.message,
              style: const TextStyle(color: AppConfig.errorColor, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<TransferCubit>().reset();
              },
              child: const Text('Назад'),
            ),
          ],
        ),
      );
    } else if (state is BluetoothDisabledState) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.blue, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Bluetooth выключен',
              style: AppConfig.screenTitleStyle,
            ),
            const SizedBox(height: AppConfig.spacingSmall),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Для поиска устройств необходимо включить Bluetooth',
                style: AppConfig.bodyTextStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    } else if (state is InfoMessageState) {
      return InfoMessageBody(state: state);
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomButton(TransferState state, TransferCubit cubit) {
    final exportProgressCubit = context.read<ExportProgressCubit>();
    if (state is InitialSearchState) {
      return PrimaryButton(
        label: 'Поиск устройств',
        onPressed: cubit.startScanning,
      );
    } else if (state is SearchingState) {
      return const PrimaryButton(
        label: 'Поиск устройств',
        onPressed: null,
        enabled: false,
      );
    } else if (state is SearchingStateWithDevices) {
      if (state.devices.isNotEmpty) {
        return PrimaryButton(
          label: 'Остановить поиск',
          onPressed: () {
            cubit.stopScanning();
          },
        );
      } else {
        return const PrimaryButton(
          label: 'Поиск устройств',
          onPressed: null,
          enabled: false,
        );
      }
    } else if (state is DeviceListState) {
      return PrimaryButton(
        label: 'Поиск устройств',
        onPressed: cubit.startScanning,
      );
    } else if (state is ConnectedState) {
      return PrimaryButton(
        label: 'Скачать архив',
        onPressed: () {
          if (state.archives.isNotEmpty) {
            cubit.downloadArchive(state.archives.first);
          }
        },
      );
    } else if (state is UploadingState) {
      return const PrimaryButton(
        label: 'Запрос...',
        onPressed: null,
        enabled: false,
      );
    } else if (state is RefreshingState) {
      return const PrimaryButton(
        label: 'Архив обновляется',
        onPressed: null,
        enabled: false,
      );
    } else if (state is TableViewState) {
      final mainData = context.read<MainData>();
      final hasActive = mainData.operations.any((op) => op.canSend);
      final hasSelected =
          mainData.operations.any((op) => op.selected && op.canSend);
      final disabled = (state).disabled;
      if (!hasActive) {
        // Все операции экспортированы — не показываем кнопку вообще
        return const SizedBox.shrink();
      }
      return Column(
        children: [
          BlocBuilder<ExportProgressCubit, ExportProgressState>(
            builder: (context, progressState) {
              if (progressState.isExporting) {
                return Padding(
                  padding: const EdgeInsets.only(
                      bottom: AppConfig.spacingExtraSmall, left: 6, right: 6),
                  child: ClipRRect(
                    borderRadius: AppConfig.mediumBorderRadius,
                    child: LinearProgressIndicator(
                      value: progressState.progress,
                      minHeight: 6,
                      color: AppConfig.secondaryColor,
                      backgroundColor: AppConfig.progressBackgroundColor,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          PrimaryButton(
            label: 'Экспортировать',
            enabled: !disabled && hasSelected && !_isRequesting,
            onPressed: !disabled && hasSelected
                ? () {
                    exportProgressCubit.start();
                    context.read<TransferCubit>().exportSelected(
                      onProgress: (progress) {
                        print('PROGRESS: ' + progress.toString());
                        exportProgressCubit.update(progress);
                      },
                      onFinish: () {
                        exportProgressCubit.finish();
                      },
                    );
                    BlocProvider.of<TransferCubit>(context)
                        .notifyTableChanged();
                  }
                : null,
          )
        ],
      );
    } else if (state is PendingArchivesState) {
      return PrimaryButton(
        label: 'Поиск устройств',
        onPressed: cubit.startScanning,
      );
    } else if (state is ExportingState) {
      return Column(children: [
        BlocBuilder<ExportProgressCubit, ExportProgressState>(
          builder: (context, progressState) {
            if (progressState.isExporting) {
              return Padding(
                padding: const EdgeInsets.only(
                    bottom: AppConfig.spacingExtraSmall, left: 6, right: 6),
                child: ClipRRect(
                  borderRadius: AppConfig.mediumBorderRadius,
                  child: LinearProgressIndicator(
                    value: progressState.progress,
                    minHeight: 6,
                    color: AppConfig.secondaryColor,
                    backgroundColor: AppConfig.progressBackgroundColor,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        const PrimaryButton(
          label: 'Отправка',
          enabled: false,
          onPressed: null,
        )
      ]);
    } else if (state is ExportSuccessState) {
      return PrimaryButton(
        label: 'На главную',
        onPressed: () {
          context.read<TransferCubit>().reset();
        },
      );
    } else if (state is NetErrorState) {
      return PrimaryButton(
        label: 'Запрос',
        onPressed: () async {
          await context.read<TransferCubit>().loadLocalArchive(state.dbPath);
        },
      );
    } else if (state is BluetoothDisabledState) {
      return Column(
        children: [
          PrimaryButton(
            label: 'Включить Bluetooth',
            onPressed: () {
              cubit.enableBluetooth();
            },
          ),
          const SizedBox(height: AppConfig.spacingSmall),
          TextButton(
            onPressed: () {
              cubit.startScanning();
            },
            child: const Text(
              'Повторить поиск',
              style: AppConfig.buttonTextStyle,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
