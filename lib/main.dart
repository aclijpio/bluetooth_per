import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/di/injection_container.dart' as di;
import 'features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'shared/shared.dart';

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
    return MaterialApp(
      title: 'Quantor Data Transfer',
      theme: AppTheme.lightTheme,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<BluetoothBloc>(),
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bluetooth),
              SizedBox(width: 12),
              Text('Quantor'),
            ],
          ),
        ),
        body: const MainScreen(),
      ),
    );
  }
}
