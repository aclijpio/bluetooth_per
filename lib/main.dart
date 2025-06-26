import 'package:bluetooth_per/features/bluetooth/presentation/bloc/unified_interface_cubit.dart';
import 'package:bluetooth_per/features/unified/presentation/pages/unified_page.dart';
import 'package:bluetooth_per/features/web/utils/cubit_provider_widget.dart';
import 'package:bluetooth_per/features/web/utils/repository_provider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection_container.dart' as di;
import 'features/bluetooth/presentation/bloc/bluetooth_bloc.dart';

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
    return RepositoryProviderWidget(
      child: CubitProviderWidget(
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => di.sl<BluetoothBloc>(),
            ),
            BlocProvider(
              create: (context) => UnifiedInterfaceCubit(),
            ),
          ],
          child: const DerviceFlowScreen(),
        ),
      ),
    );
  }
}
