import 'package:bluetooth_per/features/web/data/repositories/main_data.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import '../../features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import '../../features/bluetooth/domain/repositories/bluetooth_repository.dart';
import '../../features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:logger/logger.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Features - Bluetooth
  sl.registerFactory(
    () => BluetoothBloc(
      repository: sl(),
      mainData: sl(),
    ),
  );

  sl.registerLazySingleton<BluetoothRepository>(
    () => BluetoothRepositoryImpl(sl()),
  );

  // Core
  sl.registerLazySingleton(() => FlutterBlueClassic());

  // Web Feature
  sl.registerLazySingleton(() => MainData());

  // Core
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
