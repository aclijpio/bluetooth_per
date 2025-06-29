import 'config/device_config.dart';

/// Пример использования регулярных выражений для поиска устройств
class RegexUsageExample {
  static void demonstrateRegexPatterns() {
    print('=== Примеры использования регулярных выражений ===\n');

    // Тестовые имена устройств
    final testDevices = [
      'Quantor AAA00AA',
      'Quantor BBB00BB',
      'Quantor CCC00CC',
      'Quantor XYZ12AB',
      'Quantor DEF34GH',
      'Some Other Device',
      'Quantor INVALID',
      'quantor aaa00aa', // Проверка регистронезависимости
      'QUANTOR AAA00AA', // Проверка регистронезависимости
    ];

    print('Тестируем устройства:');
    for (final device in testDevices) {
      final matches = DeviceConfig.matchesPattern(device);
      final info = DeviceConfig.extractDeviceInfo(device);

      print('  "$device" -> ${matches ? "СОВПАДАЕТ" : "НЕ СОВПАДАЕТ"}');

      if (info != null) {
        print('    Информация: $info');
      }
    }

    print('\n=== Добавление новых шаблонов ===\n');

    // Добавляем новый шаблон для других типов устройств
    try {
      DeviceConfig.addPattern(r'Device[A-Z]{2}\d{4}'); // DeviceAA1234
      print('Добавлен новый шаблон: Device[A-Z]{2}\\d{4}');
    } catch (e) {
      print('Ошибка добавления шаблона: $e');
    }

    // Тестируем новый шаблон
    final newTestDevices = [
      'DeviceAA1234',
      'DeviceBB5678',
      'DeviceCC9999',
    ];

    print('\nТестируем новые устройства:');
    for (final device in newTestDevices) {
      final matches = DeviceConfig.matchesPattern(device);
      print('  "$device" -> ${matches ? "СОВПАДАЕТ" : "НЕ СОВПАДАЕТ"}');
    }

    print('\n=== Текущие шаблоны ===\n');
    final patterns = DeviceConfig.getPatterns();
    for (int i = 0; i < patterns.length; i++) {
      print('  $i: ${patterns[i]}');
    }

    print('\n=== Тестирование конкретных шаблонов ===\n');

    // Тестируем конкретный шаблон
    final specificPattern = r'Quantor\s+[A-Z]{3}\d{2}[A-Z]{2}';
    final testDevice = 'Quantor AAA00AA';

    final matchesSpecific =
        DeviceConfig.matchesSpecificPattern(testDevice, specificPattern);
    print(
        'Устройство "$testDevice" соответствует шаблону "$specificPattern": $matchesSpecific');
  }

  /// Пример настройки шаблонов для разных сценариев
  static void setupCustomPatterns() {
    print('\n=== Настройка пользовательских шаблонов ===\n');

    // Очищаем существующие шаблоны
    DeviceConfig.clearPatterns();
    print('Очищены существующие шаблоны');

    // Добавляем новые шаблоны
    final customPatterns = [
      r'Quantor\s+[A-Z]{3}\d{2}[A-Z]{2}', // Quantor AAA00AA
      r'Device[A-Z]{2}\d{4}', // DeviceAA1234
      r'Sensor_[A-Z]{2}_\d{3}', // Sensor_AA_123
      r'Test[A-Z]{3}\d{2}', // TestABC12
    ];

    for (final pattern in customPatterns) {
      try {
        DeviceConfig.addPattern(pattern);
        print('Добавлен шаблон: $pattern');
      } catch (e) {
        print('Ошибка добавления шаблона "$pattern": $e');
      }
    }

    // Тестируем новые шаблоны
    final testDevices = [
      'Quantor AAA00AA',
      'DeviceAA1234',
      'Sensor_AA_123',
      'TestABC12',
      'Invalid Device',
    ];

    print('\nТестируем пользовательские шаблоны:');
    for (final device in testDevices) {
      final matches = DeviceConfig.matchesPattern(device);
      print('  "$device" -> ${matches ? "СОВПАДАЕТ" : "НЕ СОВПАДАЕТ"}');
    }
  }

  /// Пример извлечения информации из имени устройства
  static void extractDeviceInformation() {
    print('\n=== Извлечение информации из устройств ===\n');

    final devices = [
      'Quantor AAA00AA',
      'DeviceAA1234',
      'Sensor_AA_123',
    ];

    for (final device in devices) {
      final info = DeviceConfig.extractDeviceInfo(device);
      print('Устройство: $device');

      if (info != null) {
        print('  Полное имя: ${info['fullName']}');
        print('  Использованный шаблон: ${info['pattern']}');
        print('  Найденные группы: ${info['matchedGroups']}');
      } else {
        print('  Информация не извлечена');
      }
      print('');
    }
  }
}

/// Запуск всех примеров
void main() {
  RegexUsageExample.demonstrateRegexPatterns();
  RegexUsageExample.setupCustomPatterns();
  RegexUsageExample.extractDeviceInformation();
}
