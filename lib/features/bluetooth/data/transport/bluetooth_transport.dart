import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_classic/flutter_blue_classic.dart';

/// Обёртка над [FlutterBlueClassic], предоставляющая минимальный
/// транспортный API для обмена «сырыми» байтами по RFCOMM.
///
/// 1. **connect(mac)** – устанавливает соединение с устройством и ждёт,
///    пока низкоуровневый [BluetoothConnection] будет готов. Если соединение
///    уже существует и активно, оно переиспользуется.
/// 2. **bytes** – широковещательный поток входящих данных.
/// 3. **write(bytes)** – отправка блока байт.
/// 4. **disconnect()** – закрывает сокет и все внутренние подписки.
class BluetoothTransport {
  BluetoothTransport(this._bluetooth);

  final FlutterBlueClassic _bluetooth;

  BluetoothConnection? _connection;
  StreamSubscription? _inputSub;
  StreamController<List<int>>? _bytesController;

  /// Широковещательный поток входящих байтов.
  Stream<List<int>> get bytes {
    _bytesController ??= StreamController<List<int>>.broadcast();
    return _bytesController!.stream;
  }

  bool get isConnected => _connection?.isConnected ?? false;

  /// Устанавливает RFCOMM-соединение с устройством [mac]. Если соединение
  /// уже активно — метод сразу возвращает управление.
  Future<void> connect(String mac) async {
    if (_connection != null && _connection!.isConnected) return;

    // Отменяем предыдущую подписку, если была.
    await _inputSub?.cancel();
    _inputSub = null;

    // Create new stream controller for this connection
    _bytesController?.close();
    _bytesController = StreamController<List<int>>.broadcast();

    _connection = await _bluetooth.connect(mac);

    if (!(_connection?.isConnected ?? false)) {
      throw Exception('Failed to connect to $mac');
    }

    // Каждую полученную порцию данных прокидываем наружу.
    _inputSub = _connection!.input?.listen(
      (data) => _bytesController?.add(data),
      onError: (error) => _bytesController?.addError(error),
      onDone: () {
        // Don't close the controller here, just mark the connection as done
        print('Bluetooth connection input stream closed');
      },
      cancelOnError: true,
    );
  }

  /// Отправляет «сырые» байты [data] через открытый сокет.
  void write(List<int> data) {
    if (!isConnected) throw StateError('Not connected');
    _connection!.output.add(Uint8List.fromList(data));
  }

  /// Закрывает сокет и освобождает ресурсы.
  Future<void> disconnect() async {
    await _inputSub?.cancel();
    _inputSub = null;
    await _connection?.close();
    _connection = null;
  }

  /// Полностью уничтожает транспорт (удобно в тестах).
  Future<void> dispose() async {
    await disconnect();
    await _bytesController?.close();
    _bytesController = null;
  }
}
