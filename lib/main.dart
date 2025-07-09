import 'package:bluetooth_per/common/widgets/app_header.dart';
import 'package:bluetooth_per/features/bluetooth/presentation/screens/flow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/di/injection_container.dart' as di;
import 'features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'features/bluetooth/presentation/bloc/device_flow_cubit.dart';
import 'core/data/main_data.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  await di.init();
  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  await Permission.storage.request();
  await Permission.manageExternalStorage.request();
  await Permission.bluetoothScan.request();
  await Permission.bluetooth.request();
  await Permission.bluetoothConnect.request();
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MainData>(create: (context) => di.sl<MainData>()),
        BlocProvider(create: (context) => di.sl<BluetoothBloc>()),
        BlocProvider(create: (context) => di.sl<DeviceFlowCubit>()),
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
