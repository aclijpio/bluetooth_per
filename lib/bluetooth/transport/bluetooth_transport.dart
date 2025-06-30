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

  /// Устанавливает RFCOMM-соединение с устройством [mac].
  /// Если после подключения нет активного сокета/потока — соединение сразу разрывается
  /// и пробрасывается ошибка наверх.
  Future<void> connect(String mac) async {
    try {
      print('🔗 [BluetoothTransport] Попытка подключения к устройству: $mac');

      // Если уже подключены – переиспользуем текущий сокет
      if (_connection != null && _connection!.isConnected) {
        print('⚠️ [BluetoothTransport] Уже есть активное соединение с $mac');
        return;
      }

      // Сброс предыдущей подписки
      await _inputSub?.cancel();
      _inputSub = null;

      print('🔗 [BluetoothTransport] Создаём RFCOMM-сокет ...');
      _connection = await _bluetooth.connect(mac);

      // Проверяем, что соединение и поток ввода действительно активны
      final connected = _connection?.isConnected ?? false;
      final hasInput = _connection?.input != null;

      if (!connected || !hasInput) {
        print(
            '❌ [BluetoothTransport] Сокет неактивен (connected=$connected, hasInput=$hasInput) – сбрасываем.');
        await _connection?.close();
        _connection = null;
        throw Exception('Active socket not available for $mac');
      }

      // Подписываемся на входящие данные
      _inputSub = _connection!.input!.listen(
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
          // Не закрываем контроллер, чтобы внешние слушатели не упали
        },
        cancelOnError: true,
      );

      print('✅ [BluetoothTransport] Подключение и подписка завершены успешно');
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
