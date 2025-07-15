# Настройка SMTP для отправки логов

## Настройка Gmail для отправки логов

### 1. Включите двухфакторную аутентификацию
- Перейдите в [Google Account Security](https://myaccount.google.com/security)
- Включите двухфакторную аутентификацию, если она еще не включена

### 2. Создайте пароль приложения
- Перейдите в [App Passwords](https://myaccount.google.com/apppasswords)
- Выберите "Другие (пользовательское имя)" и введите "Bluetooth Per App"
- Скопируйте сгенерированный пароль (16 символов)

### 3. Обновите конфигурацию в коде
В файле `lib/core/config.dart` замените:

```dart
static const String senderEmail = 'your-email@gmail.com'; // Ваш Gmail
static const String senderPassword = 'your-app-password'; // Пароль приложения из шага 2
```

## Альтернативные SMTP серверы

### Outlook/Hotmail
```dart
static const String smtpHost = 'smtp-mail.outlook.com';
static const int smtpPort = 587;
```

### Yahoo Mail
```dart
static const String smtpHost = 'smtp.mail.yahoo.com';
static const int smtpPort = 587;
```

### Яндекс Почта
```dart
static const String smtpHost = 'smtp.yandex.ru';
static const int smtpPort = 587;
```

## Безопасность

⚠️ **Важно**: Никогда не добавляйте реальные email и пароли в систему контроля версий!

Рекомендуется:
1. Создать отдельные константы в локальном файле конфигурации
2. Использовать переменные окружения
3. Или создать отдельный файл `config_local.dart` и добавить его в `.gitignore`

## Устранение неполадок

### Ошибка аутентификации
- Убедитесь, что включена двухфакторная аутентификация
- Проверьте правильность пароля приложения
- Убедитесь, что используете именно пароль приложения, а не основной пароль

### Таймаут подключения
- Проверьте интернет-соединение
- Убедитесь, что SMTP порт не заблокирован firewall
- Попробуйте другой SMTP сервер

### Ошибка TLS/SSL
- Убедитесь, что используете правильный порт (587 для TLS)
- Проверьте настройки `ssl: false` для автоматического TLS 