import 'dart:core';

/// Конфигурация для поиска Bluetooth устройств
class DeviceConfig {
  /// Регулярные выражения для поиска устройств
  static const List<String> devicePatterns = [
    r'Quantor\s+[A-Z]{3}\d{2}[A-Z]{2}', // Quantor AAA00AA
    r'Quantor\s+[A-Z]{3}\d{2}[A-Z]{2}', // Quantor BBB00BB
    r'Quantor\s+[A-Z]{3}\d{2}[A-Z]{2}', // Quantor CCC00CC
    r'^Quantor$', // Просто "Quantor" (для совместимости с Java приложением)
    r'Quantor.*', // Любое имя, начинающееся с Quantor
    r'.*Quantor.*', // Любое имя, содержащее Quantor
    r'^aclij$', // Временное решение для устройства aclij
  ];

  /// Проверяет, соответствует ли имя устройства одному из шаблонов
  static bool matchesPattern(String? deviceName) {
    if (deviceName == null || deviceName.isEmpty) {
      return false;
    }

    // Сначала проверяем точное совпадение
    if (deviceName == "Quantor AAA00AA") {
      print('✅ [DeviceConfig] Точное совпадение с "Quantor AAA00AA"');
      return true;
    }

    return devicePatterns.any((pattern) {
      try {
        final regex = RegExp(pattern, caseSensitive: false);
        final matches = regex.hasMatch(deviceName);
        if (matches) {
          print(
              '✅ [DeviceConfig] Устройство "$deviceName" соответствует паттерну: $pattern');
        }
        return matches;
      } catch (e) {
        // Если регулярное выражение некорректное, используем простую проверку
        print('⚠️ [DeviceConfig] Некорректный паттерн "$pattern": $e');
        final simpleMatch = deviceName.toLowerCase().contains('quantor');
        if (simpleMatch) {
          print(
              '✅ [DeviceConfig] Устройство "$deviceName" соответствует простой проверке');
        }
        return simpleMatch;
      }
    });
  }

  /// Проверяет, соответствует ли имя устройства конкретному шаблону
  static bool matchesSpecificPattern(String? deviceName, String pattern) {
    if (deviceName == null || deviceName.isEmpty) {
      return false;
    }

    try {
      final regex = RegExp(pattern, caseSensitive: false);
      final matches = regex.hasMatch(deviceName);
      return matches;
    } catch (e) {
      print('❌ [DeviceConfig] Некорректный паттерн "$pattern": $e');
      return false;
    }
  }

  /// Извлекает информацию из имени устройства по шаблону
  static Map<String, dynamic>? extractDeviceInfo(String? deviceName) {
    if (deviceName == null || deviceName.isEmpty) {
      return null;
    }

    for (final pattern in devicePatterns) {
      try {
        final regex = RegExp(pattern, caseSensitive: false);
        final match = regex.firstMatch(deviceName);

        if (match != null) {
          final info = {
            'fullName': deviceName,
            'pattern': pattern,
            'matchedGroups':
                match.groups([1, 2, 3]).where((g) => g != null).toList(),
          };
          print('✅ [DeviceConfig] Извлечена информация: $info');
          return info;
        }
      } catch (e) {
        print(
            '⚠️ [DeviceConfig] Ошибка извлечения информации с паттерном "$pattern": $e');
      }
    }

    return null;
  }

  /// Возвращает список шаблонов для отладки
  static List<String> getPatterns() {
    return List.from(devicePatterns);
  }

  /// Добавляет новый шаблон
  static void addPattern(String pattern) {
    // Проверяем корректность регулярного выражения
    try {
      RegExp(pattern);
      devicePatterns.add(pattern);
      print('✅ [DeviceConfig] Добавлен новый паттерн: $pattern');
    } catch (e) {
      print('❌ [DeviceConfig] Некорректный паттерн: $pattern - $e');
      throw ArgumentError('Invalid regex pattern: $pattern');
    }
  }

  /// Удаляет шаблон по индексу
  static void removePattern(int index) {
    if (index >= 0 && index < devicePatterns.length) {
      final removed = devicePatterns.removeAt(index);
      print('✅ [DeviceConfig] Удален паттерн по индексу $index: $removed');
    } else {
      print('❌ [DeviceConfig] Неверный индекс для удаления паттерна: $index');
    }
  }

  /// Очищает все шаблоны
  static void clearPatterns() {
    print('🧹 [DeviceConfig] Очищаем все паттерны');
    devicePatterns.clear();
  }
}
