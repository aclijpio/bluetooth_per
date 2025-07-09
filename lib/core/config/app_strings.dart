/// Application string constants
class AppStrings {
  AppStrings._();

  // App Info
  static const String appName = 'Quantor';
  static const String appTitle = 'Quantor Data Transfer';

  // Navigation & Actions
  static const String backToMainMenu = 'В главное меню';
  static const String back = 'Назад';
  static const String home = 'На главную';
  static const String search = 'Поиск устройств';
  static const String stopSearch = 'Остановить поиск';
  static const String downloadArchive = 'Скачать архив';
  static const String export = 'Экспортировать';
  static const String request = 'Запрос';
  static const String stop = 'Остановить';

  // Status Messages
  static const String archiveUpdateRequest = 'Запрос на обновление архива...';
  static const String archiveUpdating = 'Архив обновляется';
  static const String archiveUpdating2 = 'Архив обновляется...';
  static const String requesting = 'Запрос...';
  static const String sending = 'Отправка';
  static const String searching = 'Поиск устройств';

  // Bluetooth
  static const String bluetoothDisabled = 'Bluetooth выключен';
  static const String bluetoothDisabledMessage = 'Для поиска устройств необходимо включить Bluetooth';
  static const String enableBluetooth = 'Включить Bluetooth';

  // Categories & Headers
  static const String devices = 'Устройства';

  // Error Messages
  static const String databaseError = 'Файл не является базой данных или повреждён.';
  static const String filePathError = 'Не выбран файл базы данных.';
  static const String unknownDatabaseError = 'Неизвестная ошибка при открытии базы данных.';
  static const String exportError = 'Ошибка экспорта: код';
  static const String folderOpenError = 'Ошибка открытия папки:';

  // Progress & Status
  static const String progressLabel = 'PROGRESS: ';

  // Log Tags
  static const String logPermissions = '[Permissions]';
  static const String logDeviceFlow = '[DeviceFlowCubit]';
  static const String logBluetoothBloc = '[BluetoothBloc]';
  static const String logBluetoothRepo = '[BluetoothRepo]';
  static const String logWebLayer = '[WebLayer]';
  static const String logServerConnection = '[ServerConnection]';
  static const String logMainData = '[MainData]';

  // Permission Labels
  static const String permissionLocation = 'Location:';
  static const String permissionLocationWhenInUse = 'LocationWhenInUse:';
  static const String permissionBluetooth = 'Bluetooth:';
  static const String permissionBluetoothScan = 'BluetoothScan:';
  static const String permissionBluetoothConnect = 'BluetoothConnect:';

  // Device Names
  static const String localDeviceName = 'Local';
}