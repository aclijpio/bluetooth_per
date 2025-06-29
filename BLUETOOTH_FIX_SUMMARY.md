# Решение проблемы с Bluetooth

## Проблема
Когда вы выключаете Bluetooth, Java приложение продолжает пытаться принимать подключения, что вызывает бесконечный цикл ошибок.

## Решение

### 1. Улучшенная обработка состояния Bluetooth
- Добавлена проверка состояния Bluetooth адаптера в цикле сервера
- Сервер автоматически останавливается при выключении Bluetooth
- Добавлен слушатель состояния Bluetooth для автоматической реакции

### 2. Улучшенная обработка ошибок
- Различные типы ошибок обрабатываются по-разному
- Обычные разрывы соединения не логируются как ошибки
- Проблемы с Bluetooth адаптером приводят к остановке сервера

### 3. Корректное закрытие сокетов
- Улучшен метод `stop()` для правильного закрытия всех сокетов
- Добавлена проверка валидности сокетов перед использованием
- Исправлена ошибка с несуществующим методом `isClosed()`

## Что изменилось

### BluetoothServerManager.java
```java
// Проверка состояния Bluetooth в цикле сервера
if (!bluetoothAdapter.isEnabled()) {
    Log.d(TAG, "start: Bluetooth выключен, останавливаем сервер");
    break;
}

// Проверка валидности серверного сокета (исправлено)
if (serverSocket == null) {
    Log.d(TAG, "start: Серверный сокет null, останавливаем сервер");
    break;
}

// Улучшенная обработка ошибок
if (errorMsg != null) {
    if (errorMsg.contains("read failed") || 
        errorMsg.contains("socket") ||
        errorMsg.contains("timeout") ||
        errorMsg.contains("closed")) {
        Log.d(TAG, "start: Клиент отключился или сокет закрыт: " + errorMsg);
    } else if (errorMsg.contains("Bluetooth") || 
             errorMsg.contains("adapter")) {
        Log.d(TAG, "start: Bluetooth адаптер недоступен: " + errorMsg);
        break; // Выходим из цикла при проблемах с Bluetooth
    }
}
```

### BluetoothServerService.java
```java
// Слушатель состояния Bluetooth
private void registerBluetoothStateReceiver() {
    IntentFilter filter = new IntentFilter();
    filter.addAction(BluetoothAdapter.ACTION_STATE_CHANGED);
    bluetoothStateReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            int state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.STATE_OFF);
            if (state == BluetoothAdapter.STATE_OFF) {
                stopBluetoothServer();
            } else if (state == BluetoothAdapter.STATE_ON) {
                startBluetoothServer();
            }
        }
    };
    registerReceiver(bluetoothStateReceiver, filter);
}
```

## Исправленные ошибки

### 1. Метод `isClosed()` не существует
**Проблема:** `BluetoothServerSocket` не имеет метода `isClosed()`
**Решение:** Убрал проверку `isClosed()` и оставил только проверку на `null`

### 2. Улучшена обработка исключений
**Добавлено:** Обработка `Exception` в дополнение к `IOException`
**Результат:** Более надежная обработка всех типов ошибок

### 3. Улучшено закрытие соединений
**Добавлено:** Проверка состояния соединения перед закрытием
**Результат:** Избежание ошибок при попытке закрыть уже закрытое соединение

## Результат
Теперь при выключении Bluetooth:
1. Сервер автоматически останавливается
2. Все сокеты корректно закрываются
3. Нет бесконечного цикла ошибок
4. При включении Bluetooth сервер автоматически перезапускается
5. Нет ошибок компиляции

## Тестирование
1. Запустите Java приложение
2. Убедитесь что сервер работает
3. Выключите Bluetooth
4. Проверьте логи - сервер должен корректно остановиться
5. Включите Bluetooth
6. Сервер должен автоматически перезапуститься 