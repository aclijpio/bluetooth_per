import 'package:bluetooth_per/core/data/main_data.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import '../../features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import '../../features/bluetooth/data/transport/bluetooth_transport.dart';
import '../../features/bluetooth/domain/repositories/bluetooth_repository.dart';
import '../../features/bluetooth/presentation/bloc/transfer_cubit.dart';
import '../../common/bloc/operation_sending_cubit.dart';
import '../../core/utils/archive_sync_manager.dart';
import '../../core/utils/export_status_manager.dart';

final sl = GetIt.instance;

Future<void> init() async {
  _registerUtils();

  _registerData();

  _registerExternalDependencies();

  _registerBluetooth();
}

void _registerUtils() {
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

void _registerData() {
  sl.registerLazySingleton(() => MainData());
}

void _registerExternalDependencies() {
  sl.registerLazySingleton(() => FlutterBlueClassic());
}

void _registerBluetooth() {
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

/*
void _registerSharedComponents() {
  // State management
  sl.registerFactory(() => AppStateCubit());
}
*/

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
