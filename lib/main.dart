import 'package:bluetooth_per/features/bluetooth/presentation/bloc/unified_interface_cubit.dart';
import 'package:bluetooth_per/features/bluetooth/presentation/screens/flow_screen.dart';
import 'package:bluetooth_per/features/web/utils/cubit_provider_widget.dart';
import 'package:bluetooth_per/features/web/utils/repository_provider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
/*
import 'package:flutter_localizations/flutter_localizations.dart';
*/
import 'package:intl/intl.dart';

import 'core/di/injection_container.dart' as di;
import 'features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'features/bluetooth/presentation/bloc/device_flow_cubit.dart';
import 'features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'core/data/main_data.dart';
import 'core/utils/archive_sync_manager.dart';
import 'package:bluetooth_per/common/widgets/app_header.dart';

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
/*      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],*/
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
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
            BlocProvider(
              create: (_) => DeviceFlowCubit(
                di.sl<BluetoothRepository>(),
                di.sl<MainData>(),
              ),
            ),
          ],
          child: const Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.white,
            body: Column(
              children: [
                SafeArea(child: AppHeader()),
                Expanded(child: DeviceFlowScreen()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
