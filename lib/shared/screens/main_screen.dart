import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/app_state_cubit.dart';
import '../widgets/app_button.dart';
import '../widgets/device_card.dart';
import '../widgets/progress_widget.dart';
import '../models/app_models.dart';
import '../../features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../features/bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../features/bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../features/bluetooth/domain/entities/bluetooth_device.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppStateCubit(),
      child: const MainScreenBody(),
    );
  }
}

class MainScreenBody extends StatefulWidget {
  const MainScreenBody({super.key});

  @override
  State<MainScreenBody> createState() => _MainScreenBodyState();
}

class _MainScreenBodyState extends State<MainScreenBody> {
  @override
  void initState() {
    super.initState();
    // Инициализация Bluetooth
    context.read<BluetoothBloc>().add(CheckBluetoothStatus());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Кнопка "Назад" если нужно
            BlocBuilder<AppStateCubit, AppStateModel>(
              builder: (context, appState) {
                if (appState.state != AppState.initial) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        context.read<AppStateCubit>().reset();
                        context.read<BluetoothBloc>().add(StopScanning());
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('В главное меню'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0B78CC),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 20),

            // Заголовок
            BlocBuilder<AppStateCubit, AppStateModel>(
              builder: (context, appState) {
                return Text(
                  _getTitle(appState.state),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Основной контент
            Expanded(
              child: BlocListener<BluetoothBloc, BluetoothState>(
                listener: _handleBluetoothState,
                child: BlocBuilder<AppStateCubit, AppStateModel>(
                  builder: (context, appState) {
                    return _buildContent(context, appState);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Кнопка действия
            BlocBuilder<AppStateCubit, AppStateModel>(
              builder: (context, appState) {
                return _buildActionButton(context, appState);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle(AppState state) {
    switch (state) {
      case AppState.initial:
        return 'Quantor Data Transfer';
      case AppState.searching:
      case AppState.deviceFound:
        return 'Устройства';
      case AppState.connecting:
        return 'Подключение';
      case AppState.connected:
        return 'Выберите архив';
      case AppState.downloading:
        return 'Скачивание';
      case AppState.processing:
        return 'Обработка данных';
      case AppState.completed:
        return 'Завершено';
      case AppState.error:
        return 'Ошибка';
    }
  }

  Widget _buildContent(BuildContext context, AppStateModel appState) {
    switch (appState.state) {
      case AppState.initial:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bluetooth_searching,
                size: 80,
                color: Color(0xFF0B78CC),
              ),
              SizedBox(height: 20),
              Text(
                'Нажмите кнопку ниже для поиска\nBluetooth устройств',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );

      case AppState.searching:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Поиск устройств...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        );

      case AppState.deviceFound:
        return ListView.separated(
          itemCount: appState.devices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final device = appState.devices[index];
            return DeviceCard(
              device: device,
              onTap: () => _connectToDevice(context, device),
            );
          },
        );

      case AppState.connecting:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Подключение к ${appState.connectedDevice?.name ?? "устройству"}...',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        );

      case AppState.connected:
        return ListView.separated(
          itemCount: appState.archives.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final archive = appState.archives[index];
            return _buildArchiveCard(context, archive);
          },
        );

      case AppState.downloading:
        return Center(
          child: ProgressWidget(
            progress: appState.progress,
            title: 'Скачивание архива',
            subtitle: 'Пожалуйста, подождите...',
          ),
        );

      case AppState.processing:
        return const Center(
          child: CircularProgressWidget(
            progress: 1.0,
            text: 'Обработка данных...',
          ),
        );

      case AppState.completed:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
              SizedBox(height: 20),
              Text(
                'Данные успешно загружены\nи готовы к использованию',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        );

      case AppState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              Text(
                appState.errorMessage ?? 'Произошла ошибка',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildActionButton(BuildContext context, AppStateModel appState) {
    switch (appState.state) {
      case AppState.initial:
        return AppButton(
          text: 'Поиск устройств',
          icon: Icons.bluetooth_searching,
          onPressed: () => _startScanning(context),
        );

      case AppState.searching:
        return AppButton(
          text: 'Остановить поиск',
          icon: Icons.stop,
          onPressed: () => _stopScanning(context),
        );

      case AppState.deviceFound:
        return AppButton(
          text: 'Поиск устройств',
          icon: Icons.bluetooth_searching,
          onPressed: () => _startScanning(context),
        );

      case AppState.connected:
        if (appState.archives.isNotEmpty) {
          return AppButton(
            text: 'Скачать архив',
            icon: Icons.download,
            onPressed: () => _downloadArchive(context, appState.archives.first),
          );
        }
        return const SizedBox.shrink();

      case AppState.completed:
        return AppButton(
          text: 'Начать заново',
          icon: Icons.refresh,
          onPressed: () => context.read<AppStateCubit>().reset(),
        );

      case AppState.error:
        return AppButton(
          text: 'Попробовать снова',
          icon: Icons.refresh,
          onPressed: () => context.read<AppStateCubit>().reset(),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildArchiveCard(BuildContext context, ArchiveModel archive) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B78CC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.archive,
                color: Color(0xFF0B78CC),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    archive.fileName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    archive.formattedSize,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _handleBluetoothState(
      BuildContext context, BluetoothState bluetoothState) {
    final appCubit = context.read<AppStateCubit>();

    if (bluetoothState is BluetoothScanning) {
      appCubit.startSearching();

      // Добавляем найденные устройства
      final devices = bluetoothState.devices
          .map((d) => DeviceModel(
                name: d.name ?? '',
                macAddress: d.address,
              ))
          .toList();

      for (final device in devices) {
        appCubit.addDevice(device);
      }
    } else if (bluetoothState is BluetoothConnected) {
      // Симуляция списка архивов - в реальном приложении нужно получать от устройства
      final archives = [
        ArchiveModel(
          fileName: 'database.db',
          sizeBytes: 1024 * 1024, // 1MB
          lastModified: DateTime.now(),
        ),
      ];
      appCubit.deviceConnected(archives);
    } else if (bluetoothState is FileDownloading) {
      appCubit.updateProgress(bluetoothState.progress);
    } else if (bluetoothState is FileDownloaded) {
      appCubit.downloadCompleted();
      // Симуляция обработки
      Future.delayed(const Duration(seconds: 2), () {
        appCubit.processingCompleted();
      });
    } else if (bluetoothState is BluetoothError) {
      appCubit.showError(bluetoothState.message);
    }
  }

  void _startScanning(BuildContext context) {
    context.read<BluetoothBloc>().add(StartScanning());
  }

  void _stopScanning(BuildContext context) {
    context.read<BluetoothBloc>().add(StopScanning());
  }

  void _connectToDevice(BuildContext context, DeviceModel device) {
    final bluetoothDevice = BluetoothDeviceEntity(
      address: device.macAddress,
      name: device.name,
    );
    context.read<BluetoothBloc>().add(ConnectToDevice(bluetoothDevice));
    context.read<AppStateCubit>().connectToDevice(device);
  }

  void _downloadArchive(BuildContext context, ArchiveModel archive) {
    context.read<AppStateCubit>().startDownload();
    context.read<BluetoothBloc>().add(DownloadFile(archive.fileName));
  }
}
