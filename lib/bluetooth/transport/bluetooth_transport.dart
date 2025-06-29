import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_classic/flutter_blue_classic.dart' as classic;

/// Обёртка над [FlutterBlueClassic], предоставляющая минимальный
/// транспортный API для обмена командами по RFCOMM.
class BluetoothTransport {
  BluetoothTransport(this._bluetooth);

  final classic.FlutterBlueClassic _bluetooth;

  classic.BluetoothConnection? _connection;
  StreamSubscription? _inputSub;
  final _bytesController = StreamController<List<int>>.broadcast();

  /// Широковещательный поток входящих байтов.
  Stream<List<int>> get bytes => _bytesController.stream;

  bool get isConnected => _connection?.isConnected ?? false;

  /// Устанавливает RFCOMM-соединение с устройством [mac]
  Future<void> connect(String mac) async {
    try {
      print('🔗 [BluetoothTransport] Попытка подключения к устройству: $mac');

      if (_connection != null && _connection!.isConnected) {
        print('⚠️ [BluetoothTransport] Уже подключены к устройству: $mac');
        return;
      }

      // Отменяем предыдущую подписку, если была.
      await _inputSub?.cancel();
      _inputSub = null;

      print('🔗 [BluetoothTransport] Создаем соединение...');
      _connection = await _bluetooth.connect(mac);

      if (!(_connection?.isConnected ?? false)) {
        print(
            '❌ [BluetoothTransport] Не удалось подключиться к устройству: $mac');
        throw Exception('Failed to connect to $mac');
      }

      print(
          '✅ [BluetoothTransport] Соединение установлено с устройством: $mac');

      // Каждую полученную порцию данных прокидываем наружу.
      _inputSub = _connection!.input?.listen(
        (data) {
          print('📨 [BluetoothTransport] Получены данные: ${data.length} байт');
          _bytesController.add(data);
        },
        onError: (error) {
          print('❌ [BluetoothTransport] Ошибка при получении данных: $error');
          _bytesController.addError(error);
        },
        onDone: () {
          print('🔌 [BluetoothTransport] Соединение закрыто');
          // НЕ закрываем _bytesController здесь, чтобы избежать ошибок в репозитории
          // _bytesController.close();
        },
        cancelOnError: true,
      );

      print('✅ [BluetoothTransport] Подписка на входящие данные установлена');
    } catch (e) {
      print('❌ [BluetoothTransport] Ошибка при подключении: $e');
      rethrow;
    }
  }

  /// Отправляет команду через открытый сокет
  void sendCommand(Uint8List data) {
    try {
      if (!isConnected) {
        print(
            '❌ [BluetoothTransport] Попытка отправить данные без подключения');
        throw StateError('Not connected');
      }

      print('📤 [BluetoothTransport] Отправляем данные: ${data.length} байт');
      _connection!.output.add(data);
      print('✅ [BluetoothTransport] Данные отправлены успешно');
    } catch (e) {
      print('❌ [BluetoothTransport] Ошибка при отправке данных: $e');
      rethrow;
    }
  }

  /// Закрывает сокет и освобождает ресурсы
  Future<void> disconnect() async {
    try {
      print('🔌 [BluetoothTransport] Начинаем отключение...');

      await _inputSub?.cancel();
      _inputSub = null;
      print('✅ [BluetoothTransport] Подписка на данные отменена');

      await _connection?.close();
      _connection = null;
      print('✅ [BluetoothTransport] Соединение закрыто');

      print('✅ [BluetoothTransport] Отключение завершено успешно');
    } catch (e) {
      print('❌ [BluetoothTransport] Ошибка при отключении: $e');
      rethrow;
    }
  }

  /// Полностью уничтожает транспорт
  Future<void> dispose() async {
    try {
      print('🗑️ [BluetoothTransport] Уничтожаем транспорт...');
      await disconnect();
      await _bytesController.close();
      print('✅ [BluetoothTransport] Транспорт уничтожен');
    } catch (e) {
      print('❌ [BluetoothTransport] Ошибка при уничтожении транспорта: $e');
      rethrow;
    }
  }
}
