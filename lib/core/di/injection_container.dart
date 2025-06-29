import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import '../../bluetooth/entities/main_data.dart';
import '../../bluetooth/repositories/bluetooth_server_repository.dart';
import '../../bluetooth/transport/bluetooth_transport.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerLazySingleton(() => FlutterBlueClassic());

  sl.registerLazySingleton(() => BluetoothTransport(sl()));

  sl.registerLazySingleton(() => BluetoothServerRepository(
    sl<FlutterBlueClassic>(),
    sl<BluetoothTransport>(),
      ));

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
}
