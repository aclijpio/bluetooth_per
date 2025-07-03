import 'package:bluetooth_per/core/data/main_data.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import '../../features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import '../../features/bluetooth/data/transport/bluetooth_transport.dart';
import '../../features/bluetooth/domain/repositories/bluetooth_repository.dart';
import '../../features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'injection_container.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerFactory(
    () => BluetoothBloc(
      repository: sl(),
      mainData: sl(),
    ),
  );

  sl.registerLazySingleton(() => FlutterBlueClassic());

  sl.registerLazySingleton(() => BluetoothTransport(sl()));

  sl.registerLazySingleton<BluetoothRepository>(
    () => BluetoothRepositoryImpl(
      sl<BluetoothTransport>(),
      sl<FlutterBlueClassic>(),
    ),
  );

  sl.registerLazySingleton(() => MainData());

  sl.registerLazySingleton(() => Logger(
        printer: PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          printTime: true,
        ),
      ));

  // Features - Bluetooth
  // Data sources
  // Repositories
  // Use cases
  // BLoCs
}

/*
/// Dispose all resources and clean up dependencies
Future<void> dispose() async {
  final repository = sl<BluetoothRepository>();
  if (repository is BluetoothRepositoryImpl) {
    await repository.dispose();
  }
  await sl.reset();
}
*/
