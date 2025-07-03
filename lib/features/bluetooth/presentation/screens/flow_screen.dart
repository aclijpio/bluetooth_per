import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'dart:io';

import '../bloc/device_flow_cubit.dart';
import '../bloc/device_flow_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/device_tile.dart';
import '../widgets/archive_table.dart';
import '../widgets/progress_bar.dart';
import '../models/device.dart';
import 'package:bluetooth_per/core/di/injection_container.dart' as di;
import 'package:bluetooth_per/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:bluetooth_per/core/data/main_data.dart';
import 'package:bluetooth_per/core/utils/archive_sync_manager.dart';
import '../models/archive_entry.dart';
import 'package:bluetooth_per/common/bloc/operation_sending_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/sending_state.dart';
import 'package:bluetooth_per/common/widgets/primary_button.dart';
import 'package:bluetooth_per/common/widgets/progress_bar.dart';

class DeviceFlowScreen extends StatefulWidget {
  const DeviceFlowScreen({super.key});

  @override
  State<DeviceFlowScreen> createState() => _DeviceFlowScreenState();
}

class _DeviceFlowScreenState extends State<DeviceFlowScreen> {
  bool _hasTableSelection = false;
  bool _exportDialogShown = false;
  String? _exportError;
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<DeviceFlowCubit, DeviceFlowState>(
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
      },
      child: BlocProvider<OperationSendingCubit>(
        create: (ctx) => OperationSendingCubit(context.read<MainData>()),
        child: Scaffold(
          body: Padding(
            padding:
                const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 20),
            child: BlocBuilder<DeviceFlowCubit, DeviceFlowState>(
              builder: (context, state) {
                final cubit = context.read<DeviceFlowCubit>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    if (state is SearchingState || state is DeviceListState)
                      const Text(
                        'Устройства',
                        style: TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Expanded(child: _buildBody(context, state)),
                    const SizedBox(height: 20),
                    BlocBuilder<OperationSendingCubit, SendingState>(
                      builder: (context, sendState) {
                        if (sendState is ProcessingSendingState) {
                          return Column(
                            children: [
                              LinearProgressIndicator(value: sendState.percent),
                              const SizedBox(height: 8),
                              Text(
                                  'Экспорт: ${(sendState.percent * 100).toStringAsFixed(0)}%'),
                              const SizedBox(height: 8),
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
                              style: const TextStyle(color: Colors.red));
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

  Widget _buildBody(BuildContext context, DeviceFlowState state) {
    if (state is InitialSearchState) {
      return const SizedBox.shrink();
    } else if (state is SearchingState) {
      return _SearchingBody();
    } else if (state is DeviceListState) {
      return _DeviceListBody(devices: state.devices);
    } else if (state is ConnectedState) {
      return _ConnectedBody(state: state);
    } else if (state is UploadingState) {
      return _StatusBody(
        device: state.connectedDevice,
        text: 'Запрос на обновление архива...',
      );
    } else if (state is RefreshingState) {
      return _StatusBody(
        device: state.connectedDevice,
        text: 'Архив обновляется...',
      );
    } else if (state is DownloadingState) {
      return _DownloadingBody(state: state);
    } else if (state is TableViewState || state is ExportingState) {
      final mainData = context.read<MainData>();
      final displayName = ArchiveSyncManager.getDisplayName(
          state is TableViewState
              ? state.entry.fileName
              : (state as ExportingState).entry.fileName);
      final operations = (state is TableViewState)
          ? state.operations.where((op) => op.canSend || op.checkError).toList()
          : mainData.operations
              .where((op) => op.canSend || op.checkError)
              .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                context.read<DeviceFlowCubit>().reset();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('В главое меню'),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF0B78CC),
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: state is TableViewState && state.isLoading
                ? Center(
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(strokeWidth: 7),
                    ),
                  )
                : ArchiveTable(
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
                  ),
          ),
        ],
      );
    } else if (state is PendingArchivesState) {
      return _PendingArchivesBody(paths: state.dbPaths);
    } else if (state is ExportSuccessState) {
      // Убираем ExportSuccessState, всегда показываем таблицу
      return const SizedBox.shrink();
    } else if (state is NetErrorState) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Не удалось синхронизировать операции с сервером.\nПроверьте подключение к интернету.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<DeviceFlowCubit>().loadLocalArchive(state.dbPath);
              },
              child: Text('Повторить'),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomButton(DeviceFlowState state, DeviceFlowCubit cubit) {
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
      return Column(
        children: [
          PrimaryButton(
            label: hasActive ? 'Экспортировать' : 'Запрос',
            enabled: (_hasTableSelection || !hasActive) && !_isRequesting,
            onPressed: hasActive
                ? (_hasTableSelection
                    ? () {
                        context.read<DeviceFlowCubit>().exportSelected();
                        BlocProvider.of<DeviceFlowCubit>(context)
                            .notifyTableChanged();
                      }
                    : null)
                : () async {
                    setState(() {
                      _isRequesting = true;
                    });
                    await context
                        .read<DeviceFlowCubit>()
                        .loadLocalArchive(mainData.dbPath);
                    setState(() {
                      _isRequesting = false;
                    });
                  },
          )
        ],
      );
    } else if (state is PendingArchivesState) {
      return PrimaryButton(
        label: 'Поиск устройств',
        onPressed: cubit.startScanning,
      );
    } else if (state is ExportingState) {
      return const PrimaryButton(
        label: 'Отправка...',
        enabled: false,
        onPressed: null,
      );
    } else if (state is ExportSuccessState) {
      return PrimaryButton(
        label: 'На главную',
        onPressed: () {
          context.read<DeviceFlowCubit>().reset();
        },
      );
    } else if (state is NetErrorState) {
      return PrimaryButton(
        label: 'На главную',
        onPressed: () {
          context.read<DeviceFlowCubit>().reset();
        },
      );
    }
    return const SizedBox.shrink();
  }

  // --- body widgets ---
}

class _SearchingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Поиск устройств',
          style: TextStyle(color: Color(0xFF5F5F5F), fontSize: 24),
        ),
        SizedBox(height: 20),
        SizedBox(width: 40, height: 40, child: CircularProgressIndicator()),
      ],
    );
  }
}

class _DeviceListBody extends StatelessWidget {
  final List<Device> devices;
  const _DeviceListBody({required this.devices});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeviceFlowCubit>();
    if (devices.isEmpty) {
      return const Center(
        child: Text(
          'Устройства не обнаружены',
          style: TextStyle(color: Color(0xFF5F5F5F), fontSize: 24),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final device = devices[index];
        return DeviceTile(
          device: device,
          onTap: () => cubit.connectToDevice(device),
        );
      },
    );
  }
}

class _ConnectedBody extends StatelessWidget {
  final ConnectedState state;
  const _ConnectedBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeviceFlowCubit>();
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConnectedDeviceCard(
          name: state.connectedDevice.name.replaceAll("Quantor", ""),
          macAddress: state.connectedDevice.macAddress,
        ),
        const SizedBox(height: 40),
        // Archive label
        const Text(
          'Архив',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        ...state.archives.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => cubit.downloadArchive(a),
              borderRadius: BorderRadius.circular(27),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F2FA),
                  borderRadius: BorderRadius.circular(27),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProgressBarWithPercent(progress: 0.0),
                    SizedBox(height: 20),
                    Text(
                      'Размер: -',
                      style: TextStyle(fontSize: 16, color: Color(0xFF424242)),
                    ),
                    Text(
                      'Время загрузки: -',
                      style: TextStyle(fontSize: 16, color: Color(0xFF424242)),
                    ),
                    Text(
                      'Скорость: ',
                      style: TextStyle(fontSize: 16, color: Color(0xFF424242)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DownloadingBody extends StatelessWidget {
  final DownloadingState state;
  const _DownloadingBody({required this.state});

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  String _formatTime(double seconds) {
    final mins = seconds ~/ 60;
    final secs = (seconds % 60).toStringAsFixed(1);
    return mins > 0 ? '$mins мин $secs сек' : '$secs сек';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConnectedDeviceCard(
          name: state.connectedDevice.name.replaceAll("Quantor", ""),
          macAddress: state.connectedDevice.macAddress,
        ),
        const SizedBox(height: 40),
        // Archive label
        const Text(
          'Архив',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F2FA),
            borderRadius: BorderRadius.circular(27),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressBarWithPercent(progress: state.progress),
              const SizedBox(height: 20),
              Text(
                'Размер: '
                '${state.fileSize != null ? _formatSize(state.fileSize!) : '-'}',
                style: const TextStyle(fontSize: 16, color: Color(0xFF424242)),
              ),
              Text(
                'Время загрузки: '
                '${state.elapsedTime != null ? _formatTime(state.elapsedTime!) : '-'}',
                style: const TextStyle(fontSize: 16, color: Color(0xFF424242)),
              ),
              Text(
                'Скорость: ${state.speedLabel}',
                style: const TextStyle(fontSize: 16, color: Color(0xFF424242)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBody extends StatelessWidget {
  final Device device;
  final String text;
  const _StatusBody({required this.device, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConnectedDeviceCard(
          name: device.name.replaceAll("Quantor", ""),
          macAddress: device.macAddress,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class ArchiveTile extends StatelessWidget {
  final String name;
  final String date;
  final VoidCallback? onTap;
  const ArchiveTile(
      {super.key, required this.name, required this.date, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(27),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F2FA),
          borderRadius: BorderRadius.circular(27),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.archive_outlined,
                color: Color(0xFF0B78CC), size: 28),
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
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5F5F5F),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Color(0xFF0B78CC)),
          ],
        ),
      ),
    );
  }
}

class _PendingArchivesBody extends StatelessWidget {
  final List<String> paths;
  const _PendingArchivesBody({required this.paths});

  Future<String> _getArchiveDate(String path) async {
    // Пробуем найти дату в имени файла
    final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(path);
    if (dateMatch != null) {
      return dateMatch.group(1)!;
    }
    // Если не нашли — берём дату изменения файла
    try {
      final file = File(path);
      final modified = await file.lastModified();
      return '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
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
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
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
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ArchiveTile(
                          name: fileName,
                          date: dateStr,
                          onTap: () {
                            final cubit = context.read<DeviceFlowCubit>();
                            cubit.loadLocalArchive(p);
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

class ConnectedDeviceCard extends StatelessWidget {
  final String name;
  final String macAddress;
  const ConnectedDeviceCard(
      {super.key, required this.name, required this.macAddress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F2FA),
        borderRadius: BorderRadius.circular(27),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Подключен к: $name',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Color(0xFF222222),
            ),
          ),
/*          const SizedBox(height: 8),
          Text(
            macAddress,
            style: const TextStyle(fontSize: 16, color: Color(0xFF5F5F5F)),
          ),*/
        ],
      ),
    );
  }
}
