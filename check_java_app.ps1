# Скрипт для проверки Java Bluetooth приложения
Write-Host "🔍 Проверка Java Bluetooth приложения..." -ForegroundColor Green

# Проверяем подключенные устройства
Write-Host "📱 Подключенные устройства:" -ForegroundColor Yellow
adb devices

# Проверяем логи Java приложения
Write-Host "📋 Логи BluetoothServer:" -ForegroundColor Yellow
Write-Host "adb logcat | grep 'BluetoothServer'" -ForegroundColor Cyan

# Проверяем процессы Java приложения
Write-Host "🔍 Процессы BluetoothSender:" -ForegroundColor Yellow
adb shell ps | findstr "bluetoothsender"

# Проверяем установленные приложения
Write-Host "📦 Установленные приложения:" -ForegroundColor Yellow
adb shell pm list packages | findstr "bluetoothsender"

Write-Host "✅ Проверка завершена" -ForegroundColor Green
Write-Host ""
Write-Host "Для просмотра логов в реальном времени выполните:" -ForegroundColor Cyan
Write-Host "adb logcat | grep 'BluetoothServer'" -ForegroundColor White 