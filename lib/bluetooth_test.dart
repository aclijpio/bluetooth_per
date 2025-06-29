import 'package:bluetooth_per/bluetooth/bluetooth.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as classic;

/// Простой тест Bluetooth функциональности
class BluetoothTest {
  static Future<void> testBluetooth() async {
    print('🚀 Тестирование Bluetooth...');

    try {
      // Создаем BluetoothManager
      final bluetoothManager = BluetoothManager(
        flutterBlueClassic: classic.FlutterBlueClassic(),
        mainData: MainData(),
      );

      // Тестируем поиск устройств
      print('🔍 Поиск устройств...');
      final scanResult = await bluetoothManager.scanForDevices();

      scanResult.fold(
        (failure) {
          print('❌ Ошибка поиска: ${failure.message}');
        },
        (devices) {
          print('✅ Найдено устройств: ${devices.length}');
          for (final device in devices) {
            print('   - ${device.name} (${device.address})');
          }

          // Если найдены устройства, тестируем подключение
          if (devices.isNotEmpty) {
            _testConnection(bluetoothManager, devices.first);
          }
        },
      );
    } catch (e) {
      print('💥 Ошибка: $e');
    }
  }

  static Future<void> _testConnection(
      BluetoothManager bluetoothManager, BluetoothDevice device) async {
    print('🔗 Тестирование подключения к ${device.name}...');

    try {
      final connectResult =
          await bluetoothManager.connectAndUpdateArchive(device);

      connectResult.fold(
        (failure) {
          print('❌ Ошибка подключения: ${failure.message}');
        },
        (archiveInfo) {
          print('✅ Подключение успешно!');
          print('📁 Архив: ${archiveInfo.fileName}');

          // Тестируем скачивание
          _testDownload(bluetoothManager, archiveInfo);
        },
      );
    } catch (e) {
      print('💥 Ошибка подключения: $e');
    }
  }

  static Future<void> _testDownload(
      BluetoothManager bluetoothManager, ArchiveInfo archiveInfo) async {
    print('📥 Тестирование скачивания...');

    try {
      final downloadResult =
          await bluetoothManager.downloadArchive(archiveInfo);

      downloadResult.fold(
        (failure) {
          print('❌ Ошибка скачивания: ${failure.message}');
        },
        (path) {
          print('✅ Скачивание успешно!');
          print('📂 Путь: $path');
        },
      );
    } catch (e) {
      print('💥 Ошибка скачивания: $e');
    }
  }
}
