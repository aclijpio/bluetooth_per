import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'core/di/injection_container.dart' as di;
import 'features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import 'features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'features/bluetooth/presentation/pages/bluetooth_page.dart';

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
      title: 'Bluetooth File Transfer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (context) => BluetoothBloc(
          repository: BluetoothRepositoryImpl(FlutterBlueClassic()),
        )..add(const CheckBluetoothStatus()),
        child: const BluetoothPage(),
      ),
    );
  }
}
