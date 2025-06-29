# Bluetooth Module

Модуль для взаимодействия с Java Bluetooth сервером.

## Использование

```dart
import 'package:bluetooth_per/bluetooth/bluetooth.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

// Создаем BluetoothManager
final bluetoothManager = BluetoothManager(
  flutterBlueClassic: FlutterBlueClassic(),
  mainData: MainData(),
);

// Выполняем полный flow
final result = await bluetoothManager.executeFullFlow();
result.fold(
  (failure) => print('Ошибка: ${failure.message}'),
  (points) => print('Успех! Найдено ${points.length} точек'),
);
```

## Требования

1. Запустите Java приложение (оно установит имя Bluetooth: `Quantor AAA00AA`)
2. Включите Bluetooth на обоих устройствах
3. Предоставьте необходимые разрешения

## Отладка

Проверьте логи:
```bash
# Java приложение
adb logcat | grep "BluetoothServer"

# Flutter приложение  
flutter logs | grep "BluetoothManager"
```

## 🔧 Исправления совместимости

### 1. Синхронизирован протокол команд
- **Flutter отправляет:** `UPDATE_ARCHIVE`, `GET_ARCHIVE:filename`
- **Java ожидает:** `UPDATE_ARCHIVE`, `GET_ARCHIVE:filename` ✅

### 2. Исправлен формат передачи данных
- **Flutter формат:** 2 байта длины + UTF-8 данные
- **Java формат:** 2 байта длины + UTF-8 данные ✅

### 3. Синхронизированы имена устройств
- **Java устанавливает:** `Quantor AAA00AA`
- **Flutter ищет:** `Quantor AAA00AA` ✅

### 4. Синхронизированы ответы
- **Java отправляет:** `ARCHIVE_READY:filename`, `ERROR:message`
- **Flutter ожидает:** `ARCHIVE_READY:filename`, `ERROR:message` ✅

## 📋 Требования

### Flutter приложение
```yaml
dependencies:
  flutter_blue_classic: ^0.0.6
  permission_handler: ^11.3.0
```

### Java приложение
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
```

## 🚀 Использование

### 1. Запуск Java сервера
1. Установите и запустите Java приложение
2. Приложение автоматически установит имя Bluetooth: `Quantor AAA00AA`
3. Сервер начнет прослушивать подключения

### 2. Использование в Flutter

#### Простой пример
```dart
import 'package:bluetooth_per/bluetooth/bluetooth.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

// Создаем зависимости
final flutterBlueClassic = FlutterBlueClassic();
final mainData = MainData();

// Создаем BluetoothManager
final bluetoothManager = BluetoothManager(
  flutterBlueClassic: flutterBlueClassic,
  mainData: mainData,
);

// Выполняем полный flow
final result = await bluetoothManager.executeFullFlow();
result.fold(
  (failure) => print('Ошибка: ${failure.message}'),
  (points) => print('Успех! Найдено ${points.length} точек'),
);
```

#### Пошаговое выполнение
```dart
// 1. Поиск устройств
final scanResult = await bluetoothManager.scanForDevices();
scanResult.fold(
  (failure) => print('Ошибка поиска: ${failure.message}'),
  (devices) {
    print('Найдено устройств: ${devices.length}');
    for (final device in devices) {
      print('- ${device.name} (${device.address})');
    }
  },
);

// 2. Подключение к устройству
if (devices.isNotEmpty) {
  final device = devices.first;
  final connectResult = await bluetoothManager.connectAndUpdateArchive(device);
  connectResult.fold(
    (failure) => print('Ошибка подключения: ${failure.message}'),
    (archiveInfo) {
      print('Архив готов: ${archiveInfo.fileName}');
      
      // 3. Скачивание архива
      bluetoothManager.downloadArchive(archiveInfo).then((result) {
        result.fold(
          (failure) => print('Ошибка скачивания: ${failure.message}'),
          (path) => print('Архив извлечен в: $path'),
        );
      });
    },
  );
}
```

## 🔍 Подробное логирование

Модуль включает подробное логирование для отладки:

```
🔍 [BluetoothServerRepository] Начинаем поиск Bluetooth устройств...
🔍 [BluetoothServerRepository] Найдено устройство: Quantor AAA00AA (00:11:22:33:44:55)
✅ [BluetoothServerRepository] Устройство соответствует паттерну: Quantor AAA00AA
➕ [BluetoothServerRepository] Добавлено устройство: Quantor AAA00AA (00:11:22:33:44:55)
🔗 [BluetoothServerRepository] Подключение к устройству: Quantor AAA00AA (00:11:22:33:44:55)
✅ [BluetoothServerRepository] Подключение к устройству установлено
📤 [BluetoothServerRepository] Отправляем команду UPDATE_ARCHIVE
📨 [BluetoothServerRepository] Получены данные: 15 байт
📨 [BluetoothServerRepository] Декодированная команда: ARCHIVE_READY:data.db.gz
✅ [BluetoothServerRepository] Получена команда ARCHIVE_READY
```

## 🛠️ Отладка

### Проверка совместимости

1. **Проверьте имя Bluetooth устройства:**
   ```bash
   # В Java приложении
   adb logcat | grep "BluetoothName"
   ```

2. **Проверьте поиск устройств:**
   ```bash
   # В Flutter приложении
   flutter logs | grep "DeviceConfig"
   ```

3. **Проверьте протокол обмена:**
   ```bash
   # В Java приложении
   adb logcat | grep "BluetoothServer"
   
   # В Flutter приложении
   flutter logs | grep "BluetoothServerRepository"
   ```

### Частые проблемы

1. **Устройство не найдено:**
   - Проверьте, что Java приложение запущено
   - Убедитесь, что имя устройства установлено правильно
   - Проверьте Bluetooth разрешения

2. **Ошибка подключения:**
   - Убедитесь, что устройства находятся рядом
   - Проверьте, что Bluetooth включен на обоих устройствах
   - Проверьте логи на наличие ошибок протокола

3. **Ошибка передачи данных:**
   - Проверьте формат команд в логах
   - Убедитесь, что файлы существуют на Java устройстве
   - Проверьте размер передаваемых данных

## 📁 Структура файлов

```
lib/bluetooth/
├── bluetooth_manager.dart          # Основной класс управления
├── repositories/
│   └── bluetooth_server_repository.dart  # Репозиторий для работы с сервером
├── transport/
│   └── bluetooth_transport.dart    # Транспортный слой
├── protocol/
│   └── bluetooth_protocol.dart     # Протокол обмена командами
├── config/
│   └── device_config.dart          # Конфигурация поиска устройств
└── example_usage.dart              # Примеры использования
```

## 🔄 Обновления

### Версия 2.0
- ✅ Исправлена совместимость протоколов
- ✅ Добавлено подробное логирование
- ✅ Улучшена обработка ошибок
- ✅ Синхронизированы имена устройств
- ✅ Исправлен формат передачи данных

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи с помощью фильтров выше
2. Убедитесь, что оба приложения обновлены до последней версии
3. Проверьте совместимость версий Android/Flutter
4. Убедитесь, что все разрешения предоставлены 