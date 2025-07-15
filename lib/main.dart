import 'dart:io';

import 'package:bluetooth_per/features/bluetooth/presentation/screens/flow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'core/data/main_data.dart';
import 'core/di/injection_container.dart' as di;
import 'core/utils/log_manager.dart';
import 'core/widgets/app_header.dart';
import 'features/bluetooth/presentation/bloc/transfer_cubit.dart';
import 'features/bluetooth/presentation/bloc/transfer_state.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем логгер
  try {
    await LogManager.initialize();
    await LogManager.warning('APP', 'Приложение успешно запущено');
  } catch (e) {
    print('[ГЛАВНАЯ] Не удалось инициализировать LogManager: $e');
  }

  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Quantor Data Transfer',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    di.dispose();
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    // Запрашиваем основные разрешения в зависимости от версии Android
    List<Permission> permissionsToRequest = [
      Permission.location,
      Permission.storage,
    ];

    // Добавляем Bluetooth разрешения в зависимости от API level
    try {
      if (Platform.isAndroid) {
        permissionsToRequest.addAll([
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
        ]);
      } else {
        permissionsToRequest.addAll([
          Permission.bluetooth,
        ]);
      }
    } catch (e) {
      // Fallback для старых версий
      permissionsToRequest.add(Permission.bluetooth);
    }

    print(
        '[Main] Запрашиваем разрешения: ${permissionsToRequest.map((p) => p.toString()).join(', ')}');
    await permissionsToRequest.request();

    // Проверяем и запрашиваем разрешение на доступ ко всем файлам
    final manageStorageStatus = await Permission.manageExternalStorage.status;

    if (manageStorageStatus != PermissionStatus.granted) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Требуется разрешение'),
            content: const Text(
                'Для корректной работы с архивами приложению требуется доступ ко всем файлам. Пожалуйста, предоставьте это разрешение в настройках.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Сначала пробуем запросить разрешение программно
                  final result =
                      await Permission.manageExternalStorage.request();

                  // Если не помогло, открываем настройки
                  if (result != PermissionStatus.granted) {
                    await openAppSettings();
                  }
                },
                child: const Text('Предоставить разрешение'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MainData>(create: (context) => di.sl<MainData>()),
        BlocProvider(create: (context) => di.sl<TransferCubit>()),
      ],
      child: Builder(
        builder: (context) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              try {
                final transferCubit = context.read<TransferCubit>();
                final currentState = transferCubit.state;

                // На начальном экране разрешаем выход
                if (currentState is InitialSearchState) {
                  Navigator.of(context).pop();
                  return;
                }

                // Во время активных операций требуем двойное нажатие
                if (currentState is ExportingState ||
                    currentState is UploadingState ||
                    currentState is RefreshingState ||
                    currentState is DownloadingState) {
                  final now = DateTime.now();
                  if (_lastBackPressed == null ||
                      now.difference(_lastBackPressed!) >
                          const Duration(seconds: 2)) {
                    _lastBackPressed = now;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Нажмите еще раз для выхода из приложения'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // Двойное нажатие - выходим
                  Navigator.of(context).pop();
                  return;
                }

                // Для остальных состояний используем обычную навигацию
                final canGoBack = transferCubit.goBack();
                if (!canGoBack) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                print('[Main] Ошибка при обработке кнопки "Назад": $e');
                Navigator.of(context).pop();
              }
            }
          },
          child: Scaffold(
            body: Column(
              children: [
                SafeArea(
                  child: AppHeader(
                    onSettingsPressed: () => _openSettings(context),
                  ),
                ),
                Expanded(child: DeviceFlowScreen()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
