import 'package:bluetooth_per/core/bloc/operation_sending_cubit.dart';
import 'package:bluetooth_per/core/data/main_data.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import '../../features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import '../../features/bluetooth/data/transport/bluetooth_transport.dart';
import '../../features/bluetooth/domain/repositories/bluetooth_repository.dart';
import '../../features/bluetooth/presentation/bloc/transfer_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  await _registerUtils();
  await _registerData();
  await _registerExternalDependencies();
  await _registerBluetooth();
}

Future<void> _registerUtils() async {
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
}

Future<void> _registerData() async {
  sl.registerLazySingleton(() => MainData());
}

Future<void> _registerExternalDependencies() async {
  sl.registerLazySingleton(() => FlutterBlueClassic());
}

Future<void> _registerBluetooth() async {
  sl.registerLazySingleton(() => BluetoothTransport(sl()));

  sl.registerLazySingleton<BluetoothRepository>(
    () => BluetoothRepositoryImpl(
      sl<BluetoothTransport>(),
      sl<FlutterBlueClassic>(),
    ),
  );

  sl.registerFactory(
    () => TransferCubit(
      sl<BluetoothRepository>(),
      sl<MainData>(),
    ),
  );

  sl.registerFactory(
    () => OperationSendingCubit(sl<MainData>()),
  );
}

/// Dispose all resources and clean up dependencies
Future<void> dispose() async {
  try {
    final repository = sl<BluetoothRepository>();
    if (repository is BluetoothRepositoryImpl) {
      await repository.dispose();
    }
    
    final logger = sl<Logger>();
    logger.i('Disposing dependency injection container');
    
    await sl.reset();
  } catch (e) {
    print('Error disposing DI container: $e');
  }
}

/// Check if all required dependencies are registered
bool validateDependencies() {
  try {
    sl<Logger>();
    sl<MainData>();
    sl<FlutterBlueClassic>();
    sl<BluetoothRepository>();
    return true;
  } catch (e) {
    return false;
  }
}
