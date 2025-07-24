# Quantor Bluetooth Data Transfer

[![Flutter Version](https://img.shields.io/badge/Flutter-3.19.0-blue.svg)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.2.3-blue.svg)](https://dart.dev)

Приложение для сбора и синхронизации данных с устройств Quantor через Bluetooth соединение.

## 📋 Описание

**bluetooth_per** - это Flutter приложение, предназначенное для:
- Поиска и подключения к устройствам Quantor по Bluetooth
- Загрузки данных измерений с устройств
- Синхронизации данных с сервером
- Управления архивами данных

## 🏗️ Архитектура

Проект построен по принципам **Clean Architecture** с использованием:

- **Presentation Layer**: BLoC pattern для управления состоянием UI
- **Domain Layer**: Use Cases и Entity для бизнес-логики
- **Data Layer**: Repositories и Data Sources для работы с данными

### Структура проекта

```
lib/
├── core/                    # Основные компоненты
│   ├── bloc/               # Глобальные BLoC компоненты
│   ├── config.dart         # Конфигурация приложения
│   ├── data/               # Общие модели данных
│   ├── di/                 # Dependency Injection
│   ├── error/              # Обработка ошибок
│   ├── usecases/           # Базовые use cases
│   ├── utils/              # Утилиты
│   └── widgets/            # Переиспользуемые виджеты
├── features/               # Функциональные модули
│   ├── bluetooth/          # Bluetooth функциональность
│   │   ├── data/          # Репозитории и data sources
│   │   ├── domain/        # Use cases и entities
│   │   └── presentation/  # UI и state management
│   └── web/               # Веб API функциональность
└── main.dart              # Точка входа
```

## 🚀 Быстрый старт

### Предварительные требования

- Flutter SDK 3.19.0+
- Dart SDK 3.2.3+
- Android Studio / VS Code
- Android SDK (для Android разработки)

### Установка

1. **Клонирование репозитория**
   ```bash
   git clone <repository-url>
   cd bluetooth_per
   ```

2. **Установка зависимостей**
   ```bash
   flutter pub get
   ```

3. **Генерация mock-файлов для тестов**
   ```bash
   flutter packages pub run build_runner build
   ```

4. **Запуск приложения**
   ```bash
   flutter run
   ```

## 🔧 Разработка

### Линтинг и анализ кода

```bash
# Анализ кода
flutter analyze

# Запуск тестов
flutter test

# Проверка форматирования
dart format --set-exit-if-changed .

# Metrics анализ
flutter packages pub run dart_code_metrics:metrics analyze lib
```

### Генерация кода

```bash
# Генерация mock-файлов
flutter packages pub run build_runner build --delete-conflicting-outputs
```

## 📱 Функциональность

### Основные возможности

- ✅ Поиск Bluetooth устройств Quantor
- ✅ Подключение к устройствам
- ✅ Загрузка данных измерений
- ✅ Синхронизация с сервером
- ✅ Управление архивами
- ✅ Экспорт данных

### Технические особенности

- **State Management**: BLoC/Cubit
- **Dependency Injection**: GetIt
- **Network**: Dio + HTTP
- **Database**: SQLite (sqflite)
- **Logging**: Logger package
- **Error Handling**: Either (dartz)

## 🧪 Тестирование

### Запуск тестов

```bash
# Все тесты
flutter test

# Тесты с покрытием
flutter test --coverage

# Конкретный тест
flutter test test/features/bluetooth/domain/usecases/search_devices_usecase_test.dart
```

### Структура тестов

- **Unit tests**: `test/features/*/domain/`
- **Widget tests**: `test/features/*/presentation/`
- **Integration tests**: `integration_test/`

## 📦 Зависимости

### Основные зависимости

- `flutter_bloc` - State management
- `get_it` - Dependency injection
- `dartz` - Functional programming
- `dio` - HTTP client
- `sqflite` - Local database
- `logger` - Logging
- `permission_handler` - Permissions

### Dev зависимости

- `mockito` - Mocking for tests
- `build_runner` - Code generation
- `dart_code_metrics` - Code quality
- `flutter_lints` - Linting rules

## 🔐 Разрешения

### Android

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## 🐛 Отладка

### Логи

Приложение использует структурированное логирование:

```dart
final logger = di.sl<Logger>();
logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message');
```

### Известные проблемы

1. **Bluetooth разрешения**: Требуется ручное предоставление разрешений
2. **Файловые разрешения**: На Android 11+ требуется разрешение MANAGE_EXTERNAL_STORAGE

## 🔄 CI/CD

### GitHub Actions

- Автоматическое тестирование
- Линтинг и анализ кода
- Сборка APK для релизов

## 📄 Лицензия

Проект для внутреннего использования Quantor.

## 🤝 Участие в разработке

### Рекомендации

1. Следуйте принципам Clean Architecture
2. Используйте BLoC pattern для state management
3. Покрывайте код тестами
4. Следуйте стилю кода (dart format)
5. Используйте conventional commits

### Code Review

- Все изменения через Pull Requests
- Обязательный code review
- Проверка тестов и линтинга

## 📞 Поддержка

Для вопросов и поддержки обращайтесь к команде разработки.
