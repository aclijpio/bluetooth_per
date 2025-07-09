import 'package:bluetooth_per/features/bluetooth/presentation/screens/flow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'core/data/main_data.dart';
import 'core/di/injection_container.dart' as di;
import 'core/widgets/app_header.dart';
import 'features/bluetooth/presentation/bloc/transfer_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.storage,
    ].request();

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
      child: Scaffold(
        body: Column(
          children: [
            const SafeArea(child: AppHeader()),
            Expanded(child: DeviceFlowScreen()),
          ],
        ),
      ),
    );
  }
}
