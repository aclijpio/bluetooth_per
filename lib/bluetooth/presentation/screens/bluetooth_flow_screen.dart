import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/bluetooth_flow_cubit.dart';
import '../bloc/bluetooth_flow_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/device_tile.dart';
import '../widgets/archive_table.dart';
import '../widgets/progress_bar.dart';

class BluetoothFlowScreen extends StatefulWidget {
  const BluetoothFlowScreen({super.key});

  @override
  State<BluetoothFlowScreen> createState() => _BluetoothFlowScreenState();
}

class _BluetoothFlowScreenState extends State<BluetoothFlowScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: BlocBuilder<BluetoothFlowCubit, BluetoothFlowState>(
            builder: (context, state) {
              final cubit = context.read<BluetoothFlowCubit>();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    'Bluetooth устройства',
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
    );
  }

  Widget _buildBody(BuildContext context, BluetoothFlowState state) {
    if (state is InitialSearchState) {
      return _buildInitialState(context, state);
    } else if (state is SearchingState) {
      return _buildSearchingState(context, state);
    } else if (state is DeviceListState) {
      return _buildDeviceListState(context, state);
    } else if (state is ConnectingState) {
      return _buildConnectingState(context, state);
    } else if (state is RequestingArchiveUpdateState) {
      return _buildRequestingState(context, state);
    } else if (state is ArchiveUpdatingState) {
      return _buildArchiveUpdatingState(context, state);
    } else if (state is ArchiveReadyState) {
      return _buildArchiveReadyState(context, state);
    } else if (state is DownloadingState) {
      return _buildDownloadingState(context, state);
    } else if (state is ArchiveExtractedState) {
      return _buildArchiveExtractedState(context, state);
    } else if (state is LoadingOperationsState) {
      return _buildLoadingOperationsState(context, state);
    } else if (state is TableViewState) {
      return _buildTableViewState(context, state);
    } else if (state is ProcessingOperationsState) {
      return _buildProcessingOperationsState(context, state);
    } else if (state is UploadingPointsState) {
      return _buildUploadingPointsState(context, state);
    } else if (state is ProcessCompletedState) {
      return _buildProcessCompletedState(context, state);
    } else if (state is ErrorState) {
      return _buildErrorState(context, state);
    }

    return const SizedBox.shrink();
  }

  Widget _buildInitialState(BuildContext context, InitialSearchState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5E5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF3B30)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF3B30),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
        const Icon(
          Icons.bluetooth_searching,
          size: 80,
          color: Color(0xFF007AFF),
        ),
        const SizedBox(height: 24),
        const Text(
          'Нажмите кнопку для поиска устройств',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingState(BuildContext context, SearchingState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
        ),
        const SizedBox(height: 24),
        Text(
          state.statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF1C1C1E),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceListState(BuildContext context, DeviceListState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Найденные устройства (${state.devices.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 16),
        if (state.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFC107)),
            ),
            child: Text(
              state.errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF856404),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: state.devices.length,
            itemBuilder: (context, index) {
              return DeviceTile(
                device: state.devices[index],
                onTap: () {
                  context
                      .read<BluetoothFlowCubit>()
                      .connectToDevice(state.devices[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnectingState(BuildContext context, ConnectingState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
        ),
        const SizedBox(height: 24),
        Text(
          state.statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Устройство: ${state.device.name}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestingState(
      BuildContext context, RequestingArchiveUpdateState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
        ),
        const SizedBox(height: 24),
        Text(
          state.statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF1C1C1E),
          ),
        ),
      ],
    );
  }

  Widget _buildArchiveUpdatingState(
      BuildContext context, ArchiveUpdatingState state) {
    final duration = DateTime.now().difference(state.startTime);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
        ),
        const SizedBox(height: 24),
        Text(
          state.statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Время ожидания: $minutesм $secondsс',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  Widget _buildArchiveReadyState(
      BuildContext context, ArchiveReadyState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle,
          size: 80,
          color: Color(0xFF34C759),
        ),
        const SizedBox(height: 24),
        const Text(
          'Архив готов к скачиванию',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          state.archive.fileName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingState(BuildContext context, DownloadingState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ProgressBar(
          progress: state.progress,
          label: 'Скачивание архива',
          subtitle:
              '${state.speedLabel} • ${state.bytesReceived} / ${state.totalBytes} байт',
        ),
        const SizedBox(height: 32),
        if (state.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5E5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFF3B30)),
            ),
            child: Text(
              state.errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFFF3B30),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (state.isPaused)
          const Text(
            'Скачивание приостановлено',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFFFF9500),
            ),
          ),
      ],
    );
  }

  Widget _buildArchiveExtractedState(
      BuildContext context, ArchiveExtractedState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.folder_open,
          size: 80,
          color: Color(0xFF34C759),
        ),
        const SizedBox(height: 24),
        const Text(
          'Архив распакован',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Путь: ${state.extractedPath}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOperationsState(
      BuildContext context, LoadingOperationsState state) {
    final progress = state.totalOperations > 0
        ? state.loadedOperations / state.totalOperations
        : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ProgressBar(
          progress: progress,
          label: 'Загрузка операций',
          subtitle: '${state.loadedOperations} / ${state.totalOperations}',
        ),
      ],
    );
  }

  Widget _buildTableViewState(BuildContext context, TableViewState state) {
    return ArchiveTable(
      entry: state.archive,
      rows: state.rows,
      onSelectionChanged: (hasSelection) {
        context
            .read<BluetoothFlowCubit>()
            .onTableSelectionChanged(hasSelection);
      },
    );
  }

  Widget _buildProcessingOperationsState(
      BuildContext context, ProcessingOperationsState state) {
    final progress = state.totalOperations > 0
        ? state.processedOperations / state.totalOperations
        : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ProgressBar(
          progress: progress,
          label: 'Обработка операций',
          subtitle: 'Найдено ${state.foundDifferentPoints} отличающихся точек',
        ),
      ],
    );
  }

  Widget _buildUploadingPointsState(
      BuildContext context, UploadingPointsState state) {
    final progress =
        state.totalPoints > 0 ? state.uploadedPoints / state.totalPoints : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ProgressBar(
          progress: progress,
          label: state.statusMessage,
          subtitle: '${state.uploadedPoints} / ${state.totalPoints} точек',
        ),
      ],
    );
  }

  Widget _buildProcessCompletedState(
      BuildContext context, ProcessCompletedState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle,
          size: 80,
          color: Color(0xFF34C759),
        ),
        const SizedBox(height: 24),
        const Text(
          'Процесс завершен успешно!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Обработано ${state.totalPoints} точек\nНайдено ${state.differentPoints} отличающихся',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, ErrorState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline,
          size: 80,
          color: Color(0xFFFF3B30),
        ),
        const SizedBox(height: 24),
        Text(
          state.errorMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        if (state.errorDetails != null) ...[
          const SizedBox(height: 16),
          Text(
            state.errorDetails!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomButton(
      BluetoothFlowState state, BluetoothFlowCubit cubit) {
    if (state is InitialSearchState) {
      return PrimaryButton(
        label: 'Поиск устройств',
        onPressed: cubit.startScanning,
        enabled: state.canRetry,
      );
    } else if (state is SearchingState) {
      return PrimaryButton(
        label: 'Поиск...',
        onPressed: null,
        enabled: false,
        isLoading: true,
      );
    } else if (state is DeviceListState) {
      return PrimaryButton(
        label: 'Повторить поиск',
        onPressed: cubit.startScanning,
      );
    } else if (state is ConnectingState ||
        state is RequestingArchiveUpdateState ||
        state is ArchiveUpdatingState) {
      return PrimaryButton(
        label: 'Отмена',
        onPressed: cubit.cancel,
      );
    } else if (state is ArchiveReadyState) {
      return PrimaryButton(
        label: 'Скачать архив',
        onPressed: () => cubit.downloadArchive(state.archive),
      );
    } else if (state is DownloadingState) {
      return PrimaryButton(
        label: 'Отмена',
        onPressed: cubit.cancel,
      );
    } else if (state is TableViewState) {
      return PrimaryButton(
        label: 'Экспортировать',
        enabled: state.hasSelection,
        onPressed: state.hasSelection
            ? () {
                // Здесь логика экспорта
                cubit.executeFullProcess();
              }
            : null,
      );
    } else if (state is ProcessCompletedState) {
      return PrimaryButton(
        label: 'Начать заново',
        onPressed: cubit.startScanning,
      );
    } else if (state is ErrorState) {
      return PrimaryButton(
        label: 'Повторить',
        onPressed: state.canRetry ? cubit.retry : null,
        enabled: state.canRetry,
      );
    }

    return const SizedBox.shrink();
  }
}
