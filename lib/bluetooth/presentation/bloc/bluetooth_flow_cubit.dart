import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bluetooth_manager.dart';
import '../../entities/bluetooth_device.dart' as bt_entity;
import '../../entities/operation.dart';
import '../../entities/point.dart';
import '../models/device.dart';
import '../models/archive_entry.dart';
import '../models/table_row_data.dart';
import 'bluetooth_flow_state.dart';
import '../../../core/error/failures.dart';

/// Cubit для управления UI состоянием Bluetooth процесса
/// Обрабатывает все возможные сценарии и ошибки
class BluetoothFlowCubit extends Cubit<BluetoothFlowState> {
  BluetoothFlowCubit({required this.bluetoothManager})
      : super(const InitialSearchState()) {
    _setupErrorHandling();
  }

  final BluetoothManager bluetoothManager;
  StreamSubscription? _processSubscription;
  Device? _currentDevice;
  ArchiveEntry? _currentArchive;
  Timer? _timeoutTimer;
  bool _isProcessRunning = false;

  // ───────── UI actions ──────────

  /// Начать поиск устройств
  void startScanning() {
    if (_isProcessRunning) return;

    emit(const SearchingState());
    _startTimeoutTimer(const Duration(seconds: 15));

    bluetoothManager.scanForDevices().then((result) {
      _cancelTimeoutTimer();

      result.fold(
        (failure) {
          emit(InitialSearchState(
            errorMessage: _getErrorMessage(failure),
            canRetry: true,
          ));
        },
        (devices) {
          if (devices.isEmpty) {
            emit(const InitialSearchState(
              errorMessage:
                  'Устройства не найдены. Проверьте, что Bluetooth включен и устройства доступны.',
              canRetry: true,
            ));
          } else {
            final uiDevices = devices
                .map((d) => Device(
                      name: d.name ?? 'Unknown',
                      macAddress: d.address,
                    ))
                .toList();

            emit(DeviceListState(devices: uiDevices));

            // Автоматически подключаемся к первому устройству
            if (uiDevices.length == 1) {
              connectToDevice(uiDevices.first);
            }
          }
        },
      );
    });
  }

  /// Подключиться к устройству
  void connectToDevice(Device device) {
    if (_isProcessRunning) return;

    _currentDevice = device;
    emit(ConnectingState(device: device));
    _startTimeoutTimer(const Duration(seconds: 30));

    final btDevice = bt_entity.BluetoothDevice(
      address: device.macAddress,
      name: device.name,
    );

    bluetoothManager.connectAndUpdateArchive(btDevice).then((result) {
      _cancelTimeoutTimer();

      result.fold(
        (failure) {
          emit(ErrorState(
            errorMessage: _getErrorMessage(failure),
            canRetry: true,
            lastConnectedDevice: device,
          ));
        },
        (archiveInfo) {
          _currentArchive = ArchiveEntry(
            fileName: archiveInfo.fileName,
            path: archiveInfo.path,
            createdAt: archiveInfo.createdAt,
            sizeBytes: archiveInfo.fileSize ?? 0,
          );

          emit(ArchiveReadyState(
            connectedDevice: device,
            archive: _currentArchive!,
          ));

          // Даем серверу время закрыть соединение после ARCHIVE_READY
          Future.delayed(const Duration(seconds: 1)).then((_) {
            // Автоматически начинаем скачивание
            downloadArchive(_currentArchive!);
          });
        },
      );
    });
  }

  /// Скачать архив
  void downloadArchive(ArchiveEntry archive) {
    if (_isProcessRunning) return;

    _currentArchive = archive;
    emit(DownloadingState(
      connectedDevice: _currentDevice!,
      archive: _currentArchive!,
      progress: 0.0,
      speedLabel: '0 B/s',
      bytesReceived: 0,
      totalBytes: _currentArchive!.sizeBytes,
      startTime: DateTime.now(),
    ));

    _startTimeoutTimer(const Duration(minutes: 5));

    // Здесь должна быть логика скачивания с прогрессом
    // Пока используем симуляцию
    _simulateDownload(archive);
  }

  /// Выполнить полный процесс
  void executeFullProcess() async {
    if (_isProcessRunning) return;

    _isProcessRunning = true;
    emit(const SearchingState(statusMessage: 'Начинаем полный процесс...'));

    try {
      // Шаг 1: Поиск устройств
      emit(const SearchingState(statusMessage: 'Поиск Bluetooth устройств...'));
      final scanResult = await bluetoothManager.scanForDevices();

      final devices = await scanResult.fold(
        (failure) {
          _isProcessRunning = false;
          emit(ErrorState(
            errorMessage: _getErrorMessage(failure),
            canRetry: true,
            lastConnectedDevice: _currentDevice,
          ));
          return <bt_entity.BluetoothDevice>[];
        },
        (devices) => devices,
      );

      if (devices.isEmpty) {
        _isProcessRunning = false;
        emit(ErrorState(
          errorMessage: 'Устройства не найдены',
          canRetry: true,
          lastConnectedDevice: _currentDevice,
        ));
        return;
      }

      // Берем первое устройство
      final device = devices.first;
      _currentDevice = Device(
        name: device.name ?? 'Unknown',
        macAddress: device.address,
      );

      // Шаг 2: Подключение и обновление архива
      emit(ConnectingState(device: _currentDevice!));
      final archiveResult =
          await bluetoothManager.connectAndUpdateArchive(device);

      final archiveInfo = await archiveResult.fold(
        (failure) {
          _isProcessRunning = false;
          emit(ErrorState(
            errorMessage: _getErrorMessage(failure),
            canRetry: true,
            lastConnectedDevice: _currentDevice,
          ));
          return null;
        },
        (archiveInfo) => archiveInfo,
      );

      if (archiveInfo == null) return;

      _currentArchive = ArchiveEntry(
        fileName: archiveInfo.fileName,
        path: archiveInfo.path,
        createdAt: DateTime.now(),
        sizeBytes: archiveInfo.fileSize ?? 0,
      );

      // Даем серверу время закрыть соединение после ARCHIVE_READY
      await Future.delayed(const Duration(seconds: 1));

      // Шаг 3: Скачивание архива
      emit(DownloadingState(
        connectedDevice: _currentDevice!,
        archive: _currentArchive!,
        progress: 0.0,
        speedLabel: '0 B/s',
        bytesReceived: 0,
        totalBytes: _currentArchive!.sizeBytes,
        startTime: DateTime.now(),
      ));

      final downloadResult =
          await bluetoothManager.downloadArchive(archiveInfo);

      final extractedPath = await downloadResult.fold(
        (failure) {
          _isProcessRunning = false;
          emit(ErrorState(
            errorMessage: _getErrorMessage(failure),
            canRetry: true,
            lastConnectedDevice: _currentDevice,
          ));
          return null;
        },
        (extractedPath) => extractedPath,
      );

      if (extractedPath == null) return;

      // Шаг 4: Загрузка операций
      emit(LoadingOperationsState(
        connectedDevice: _currentDevice!,
        archive: _currentArchive!,
        extractedPath: extractedPath,
        loadedOperations: 0,
        totalOperations: 1,
      ));

      final operationsResult =
          await bluetoothManager.loadOperationsFromArchive(extractedPath);

      final operations = await operationsResult.fold(
        (failure) {
          _isProcessRunning = false;
          emit(ErrorState(
            errorMessage: _getErrorMessage(failure),
            canRetry: true,
            lastConnectedDevice: _currentDevice,
          ));
          return <Operation>[];
        },
        (operations) => operations,
      );

      if (operations.isEmpty) {
        _isProcessRunning = false;
        emit(ErrorState(
          errorMessage: 'Операции не найдены в архиве',
          canRetry: true,
          lastConnectedDevice: _currentDevice,
        ));
        return;
      }

      // Шаг 5: Обработка операций
      emit(ProcessingOperationsState(
        connectedDevice: _currentDevice!,
        archive: _currentArchive!,
        processedOperations: 0,
        totalOperations: operations.length,
        foundDifferentPoints: 0,
      ));

      final pointsResult = await bluetoothManager.processOperations(operations);

      final points = await pointsResult.fold(
        (failure) {
          _isProcessRunning = false;
          emit(ErrorState(
            errorMessage: _getErrorMessage(failure),
            canRetry: true,
            lastConnectedDevice: _currentDevice,
          ));
          return <Point>[];
        },
        (points) => points,
      );

      // Шаг 6: Отправка на сервер
      if (points.isNotEmpty) {
        emit(UploadingPointsState(
          connectedDevice: _currentDevice!,
          uploadedPoints: 0,
          totalPoints: points.length,
          statusMessage: 'Отправка точек на сервер...',
        ));

        final sendResult = await bluetoothManager.sendPointsToServer(points);

        await sendResult.fold(
          (failure) {
            print('⚠️ Предупреждение: ${failure.message}');
          },
          (statusCode) {
            print('✅ Отправка завершена со статусом: $statusCode');
          },
        );
      }

      // Шаг 7: Отключение
      await bluetoothManager.disconnect();

      // Завершение
      _isProcessRunning = false;
      emit(ProcessCompletedState(
        connectedDevice: _currentDevice!,
        archive: _currentArchive!,
        totalPoints: points.length,
        differentPoints: points.length,
        extractedPath: extractedPath,
      ));
    } catch (e) {
      _isProcessRunning = false;
      emit(ErrorState(
        errorMessage: 'Неожиданная ошибка: $e',
        canRetry: true,
        lastConnectedDevice: _currentDevice,
      ));
    }
  }

  /// Повторить процесс
  void retry() {
    if (_currentDevice != null) {
      connectToDevice(_currentDevice!);
    } else {
      startScanning();
    }
  }

  /// Отменить текущий процесс
  void cancel() {
    _isProcessRunning = false;
    _cancelTimeoutTimer();
    _processSubscription?.cancel();
    emit(const InitialSearchState(canRetry: true));
  }

  /// Обработать выбор в таблице
  void onTableSelectionChanged(bool hasSelection) {
    if (state is TableViewState) {
      final currentState = state as TableViewState;
      emit(TableViewState(
        connectedDevice: currentState.connectedDevice,
        archive: currentState.archive,
        rows: currentState.rows,
        hasSelection: hasSelection,
      ));
    }
  }

  // ───────── Private methods ──────────

  void _setupErrorHandling() {
    // Обработка ошибок соединения
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (state is DownloadingState && _isProcessRunning) {
        // Проверяем, не потеряли ли соединение
        // Здесь можно добавить ping или проверку состояния соединения
      }
    });
  }

  void _startTimeoutTimer(Duration duration) {
    _cancelTimeoutTimer();
    _timeoutTimer = Timer(duration, () {
      if (_isProcessRunning) {
        emit(ErrorState(
          errorMessage: 'Превышено время ожидания',
          errorDetails:
              'Операция не завершилась за ${duration.inSeconds} секунд',
          canRetry: true,
          lastConnectedDevice: _currentDevice,
        ));
        _isProcessRunning = false;
      }
    });
  }

  void _cancelTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  String _getErrorMessage(Failure failure) {
    if (failure is BluetoothFailure) {
      return 'Ошибка Bluetooth: ${failure.message}';
    } else if (failure is ConnectionFailure) {
      return 'Ошибка соединения: ${failure.message}';
    } else if (failure is FileOperationFailure) {
      return 'Ошибка файловой операции: ${failure.message}';
    } else {
      return 'Неизвестная ошибка: ${failure.message}';
    }
  }

  void _simulateDownload(ArchiveEntry archive) {
    int bytesReceived = 0;
    final totalBytes =
        archive.sizeBytes > 0 ? archive.sizeBytes : 1024 * 1024; // 1MB default

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isProcessRunning) {
        timer.cancel();
        return;
      }

      bytesReceived += 1024; // 1KB per tick
      final progress = bytesReceived / totalBytes;

      if (progress >= 1.0) {
        timer.cancel();
        _onDownloadComplete(archive);
      } else {
        emit(DownloadingState(
          connectedDevice: _currentDevice!,
          archive: archive,
          progress: progress,
          speedLabel: '10 KB/s',
          bytesReceived: bytesReceived,
          totalBytes: totalBytes,
          startTime: DateTime.now(),
        ));
      }
    });
  }

  void _onDownloadComplete(ArchiveEntry archive) {
    emit(ArchiveExtractedState(
      connectedDevice: _currentDevice!,
      archive: archive,
      extractedPath: 'Download/quan',
    ));

    // Переходим к загрузке операций
    _loadOperations(archive);
  }

  void _loadOperations(ArchiveEntry archive) {
    emit(LoadingOperationsState(
      connectedDevice: _currentDevice!,
      archive: archive,
      extractedPath: 'Download/quan',
      loadedOperations: 0,
      totalOperations: 10,
    ));

    // Симуляция загрузки операций
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isProcessRunning) {
        timer.cancel();
        return;
      }

      final currentState = state as LoadingOperationsState;
      final loaded = currentState.loadedOperations + 1;

      if (loaded >= currentState.totalOperations) {
        timer.cancel();
        _showTable(archive);
      } else {
        emit(LoadingOperationsState(
          connectedDevice: currentState.connectedDevice,
          archive: currentState.archive,
          extractedPath: currentState.extractedPath,
          loadedOperations: loaded,
          totalOperations: currentState.totalOperations,
        ));
      }
    });
  }

  void _showTable(ArchiveEntry archive) {
    final rows = List<TableRowData>.generate(
      10,
      (index) => TableRowData(
        date: DateTime.now().subtract(Duration(days: index)),
        wellId: 'Well-${index + 1}',
        operationType: 'Operation ${index + 1}',
        pointCount: (index + 1) * 100,
      ),
    );

    emit(TableViewState(
      connectedDevice: _currentDevice!,
      archive: archive,
      rows: rows,
    ));
  }

  @override
  Future<void> close() {
    _cancelTimeoutTimer();
    _processSubscription?.cancel();
    return super.close();
  }
}
