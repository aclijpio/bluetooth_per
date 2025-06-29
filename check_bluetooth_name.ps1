# Скрипт для проверки Bluetooth имени устройства
Write-Host "🔍 Проверка Bluetooth имени устройства..." -ForegroundColor Green

# Проверяем подключенные устройства
Write-Host "📱 Подключенные устройства:" -ForegroundColor Yellow
adb devices

# Проверяем Bluetooth настройки
Write-Host "📋 Bluetooth настройки:" -ForegroundColor Yellow
adb shell settings get global bluetooth_name

# Проверяем Bluetooth адаптер
Write-Host "🔧 Bluetooth адаптер:" -ForegroundColor Yellow
adb shell dumpsys bluetooth | findstr "BluetoothAdapter"

# Проверяем активные Bluetooth соединения
Write-Host "🔗 Активные Bluetooth соединения:" -ForegroundColor Yellow
adb shell dumpsys bluetooth | findstr "Connected"

Write-Host "✅ Проверка завершена" -ForegroundColor Green
Write-Host ""
Write-Host "Для просмотра логов Java приложения:" -ForegroundColor Cyan
Write-Host "adb logcat | findstr 'BluetoothNameManager'" -ForegroundColor White
Write-Host ""
Write-Host "Для просмотра всех Bluetooth логов:" -ForegroundColor Cyan
Write-Host "adb logcat | findstr 'Bluetooth'" -ForegroundColor White 