import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';

import '../bloc/device_flow_cubit.dart';
import '../bloc/device_flow_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/device_tile.dart';
import '../widgets/archive_table.dart';
import '../widgets/progress_bar.dart';
import '../widgets/simulated_progress_bar.dart';
import '../models/device.dart';

class DeviceFlowScreen extends StatefulWidget {
  const DeviceFlowScreen({super.key});

  @override
  State<DeviceFlowScreen> createState() => _DeviceFlowScreenState();
}

class _DeviceFlowScreenState extends State<DeviceFlowScreen> {
  bool _hasTableSelection = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DeviceFlowCubit(),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: BlocBuilder<DeviceFlowCubit, DeviceFlowState>(
              builder: (context, state) {
                final cubit = context.read<DeviceFlowCubit>();
                // Build main column with header, body and bottom button.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Text(
                      'Устройства',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium!
                          .copyWith(color: const Color(0xFF222222)),
                    ),
                    const SizedBox(height: 20),
                    // Body (expands)
                    Expanded(child: _buildBody(context, state)),
                    const SizedBox(height: 20),
                    // Bottom button which varies by state
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
    } else if (state is TableViewState) {
      return ArchiveTable(
        entry: state.entry,
        rows: state.rows,
        onSelectionChanged: (selected) {
          setState(() => _hasTableSelection = selected);
        },
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
      return PrimaryButton(
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
      return PrimaryButton(
        label: 'Экспортировать',
        enabled: _hasTableSelection,
        onPressed: _hasTableSelection ? _showExportDialog : null,
      );
    }
    return const SizedBox.shrink();
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.16),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSB) {
            // no internal progress logic – SimulatedProgressBar handles animation

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 42,
                      vertical: 31,
                    ),
                    child: LayoutBuilder(
                      builder: (context, cons) {
                        final trackWidth = cons.maxWidth - 72;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Загрузка операций',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF222222),
                              ),
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: trackWidth + 72,
                              child: SimulatedProgressBar(
                                duration: const Duration(seconds: 5),
                              ),
                            ),
                            const SizedBox(height: 40),
                            _cancelButton(ctx),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _cancelButton(BuildContext ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Container(
          width: 283,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF0B78CC),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Отменить',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Color(0xFFF0F0F0),
            ),
          ),
        ),
      );

  // --- body widgets ---
}

class _SearchingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
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
    return ListView(
      children: [
        // Connected Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F2FA),
            borderRadius: BorderRadius.circular(27),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Подключен к: ${state.connectedDevice.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.connectedDevice.macAddress,
                style: const TextStyle(fontSize: 16, color: Color(0xFF5F5F5F)),
              ),
            ],
          ),
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
        // Archive container(s)
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
                child: Text(
                  a.fileName,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFF222222),
                  ),
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // Connected device card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F2FA),
            borderRadius: BorderRadius.circular(27),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Подключен к: ${state.connectedDevice.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.connectedDevice.macAddress,
                style: const TextStyle(fontSize: 16, color: Color(0xFF5F5F5F)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        // Progress container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F2FA),
            borderRadius: BorderRadius.circular(27),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.entry.fileName,
                style: const TextStyle(fontSize: 20, color: Color(0xFF222222)),
              ),
              const SizedBox(height: 20),
              ProgressBarWithPercent(progress: state.progress),
              const SizedBox(height: 20),
              const Text(
                'Размер:',
                style: TextStyle(fontSize: 16, color: Color(0xFF424242)),
              ),
              const Text(
                'Время загрузки:',
                style: TextStyle(fontSize: 16, color: Color(0xFF424242)),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F2FA),
            borderRadius: BorderRadius.circular(27),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Подключен к: ${device.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                device.macAddress,
                style: const TextStyle(fontSize: 16, color: Color(0xFF5F5F5F)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
