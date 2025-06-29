import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as classic;

import 'core/di/injection_container.dart' as di;
import 'bluetooth/presentation/screens/bluetooth_flow_screen.dart';
import 'bluetooth/presentation/bloc/bluetooth_flow_cubit.dart';
import 'bluetooth/bluetooth_manager.dart';
import 'bluetooth/entities/main_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantor Data Transfer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quantor Bluetooth Manager'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => BluetoothFlowCubit(
              bluetoothManager: BluetoothManager(
                flutterBlueClassic: classic.FlutterBlueClassic(),
                mainData: di.sl<MainData>(),
              ),
            ),
          ),
        ],
        child: const BluetoothFlowScreen(),
      ),
    );
  }
}
