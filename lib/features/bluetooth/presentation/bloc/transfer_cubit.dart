import 'package:bluetooth_per/core/config.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import 'package:bluetooth_per/core/utils/archive_sync_manager.dart';
import 'package:bluetooth_per/core/utils/background_operations_manager.dart';
import 'package:bluetooth_per/core/utils/export_status_manager.dart';
import 'package:bluetooth_per/core/widgets/send_logs_button.dart';
import 'package:bluetooth_per/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:bluetooth_per/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/main_data.dart';
import '../models/archive_entry.dart';
import '../models/device.dart';
import 'transfer_state.dart';

class TransferCubit extends Cubit<TransferState> {
  final BluetoothRepository _repository;
  final MainData _mainData;
  final List<Device> _lastFoundDevices = [];
  bool _searching = false;

  TransferCubit(this._repository, this._mainData)
      : super(const InitialSearchState()) {
    _loadPending();
  }

  Future<void> _loadPending() async {
    final pending = await ArchiveSyncManager.getPending();
    if (pending.isNotEmpty) {
      emit(PendingArchivesState(pending));
    } else {
      emit(const InitialSearchState());
    }
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    }
    final kB = bytesPerSec / 1024;
    if (kB < 1024) return '${kB.toStringAsFixed(1)} KB/s';
    final mB = kB / 1024;
    return '${mB.toStringAsFixed(1)} MB/s';
  }

  BluetoothDeviceEntity _toEntity(Device d) =>
      BluetoothDeviceEntity(address: d.macAddress, name: d.name);

  Device _toUi(BluetoothDeviceEntity e) =>
      Device(name: e.name ?? '', macAddress: e.address);

  Future<void> enableBluetooth() async {
    _loadPending();

    final enableResult = await _repository.enableBluetooth();
    enableResult.fold(
      (failure) {
        if (failure.message.contains('отклонил')) {
          emit(const BluetoothDisabledState());
        } else {
          emit(const BluetoothDisabledState());
        }
      },
      (success) {
        _loadPending();
      },
    );
  }

  Future<void> startScanning() async {
    await BackgroundOperationsManager.ensureWakeLockForOperation();
    _searching = true;
    emit(const SearchingState());

    _lastFoundDevices.clear();
    final result = await _repository.scanForDevices(
      onDeviceFound: (entity) {
        if (!_searching) return;
        final device = _toUi(entity);
        if (!_lastFoundDevices.any((d) => d.macAddress == device.macAddress)) {
          _lastFoundDevices.add(device);

          emit(SearchingStateWithDevices(List<Device>.from(_lastFoundDevices)));
        }
      },
    );

    result.fold(
      (failure) {
        if (!_searching || _isActiveState()) return;
        _searching = false;
        BackgroundOperationsManager.releaseWakeLockAfterOperation();

        if (failure.message == 'BLUETOOTH_DISABLED') {
          emit(const BluetoothDisabledState());
        } else if (failure.message.contains('разрешение')) {
          emit(InfoMessageState(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.security,
                  size: 64,
                  color: AppConfig.errorColor,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Нет разрешений для поиска устройств',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppConfig.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  failure.message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppConfig.tertiaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            buttonText: 'К списку устройств',
            onButtonPressed: () {
              emit(DeviceListState(_lastFoundDevices));
            },
          ));
        } else {
          emit(InfoMessageState(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppConfig.errorColor,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ошибка поиска устройств',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppConfig.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  failure.message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppConfig.tertiaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            buttonText: 'К списку устройств',
            onButtonPressed: () {
              emit(DeviceListState(_lastFoundDevices));
            },
          ));
        }
      },
      (entities) {
        if (!_searching || _isActiveState()) return;
        final devices = entities.map(_toUi).toList();
        _lastFoundDevices.clear();
        _lastFoundDevices.addAll(devices);
        _searching = false;
        BackgroundOperationsManager.releaseWakeLockAfterOperation();
        if (devices.isEmpty) {
          _loadPending();
        } else {
          emit(DeviceListState(devices));
        }
      },
    );
  }

  bool _isActiveState() {
    return state is UploadingState ||
        state is RefreshingState ||
        state is DownloadingState ||
        state is ConnectedState ||
        state is TableViewState ||
        state is ExportingState ||
        state is NetErrorState ||
        (state is InfoMessageState) ||
        state is BluetoothDisabledState;
  }

  Future<void> connectToDevice(Device device) async {
    await BackgroundOperationsManager.ensureWakeLockForOperation();
    _searching = false;
    _repository.cancelScan();
    emit(UploadingState(device));

    try {
      final connectRes = await _repository
          .connectToDevice(_toEntity(device))
          .timeout(AppConfig.deviceFlowTimeout);

      bool connected = false;
      connectRes.fold(
        (failure) {
          BackgroundOperationsManager.releaseWakeLockAfterOperation();
          emit(DeviceListState(_lastFoundDevices));
        },
        (_) {
          connected = true;
        },
      );

      if (!connected) {
        BackgroundOperationsManager.releaseWakeLockAfterOperation();
        return;
      }

      try {
        bool receivedAnyResponse = false;

        await for (final status in _repository.requestArchiveUpdate().timeout(
          AppConfig.deviceFlowTimeout,
          onTimeout: (sink) {
            sink.close();
          },
        )) {
          receivedAnyResponse = true;

          if (status == 'ARCHIVE_UPDATING') {
            emit(RefreshingState(device));
          } else if (status == 'ARCHIVE_READY' ||
              status.startsWith('ARCHIVE_READY:')) {
            break;
          } else if (status == 'NOT_CONNECTED') {
            throw Exception('Соединение с устройством потеряно');
          }
        }

        if (!receivedAnyResponse) {
          throw Exception('Нет ответа от устройства');
        }
      } catch (e) {
        String errorTitle = 'Ошибка связи с устройством';
        String errorMessage = 'Проверьте соединение и повторите попытку';
        IconData errorIcon = Icons.error_outline;
        Color iconColor = Colors.red.withOpacity(0.7);

        if (e.toString().contains('Нет ответа от устройства')) {
          errorTitle = 'Нет ответа от устройства';
          errorMessage =
              'Устройство не отвечает на запросы.\nПроверьте:\n• Запущен ли ТМС на устройстве\n• Стабильность Bluetooth соединения';
          errorIcon = Icons.bluetooth_disabled;
          iconColor = Colors.orange.withOpacity(0.7);
        } else if (e.toString().contains('Соединение с устройством потеряно')) {
          errorTitle = 'Соединение потеряно';
          errorMessage =
              'Bluetooth соединение прервано.\nПереподключитесь к устройству';
          errorIcon = Icons.bluetooth_disabled;
          iconColor = Colors.red.withOpacity(0.7);
        } else if (e.toString().contains('TimeoutException')) {
          errorTitle = 'Превышено время ожидания';
          errorMessage =
              'Устройство не ответило в течение 30 секунд.\nПопробуйте еще раз';
          errorIcon = Icons.access_time;
          iconColor = Colors.orange.withOpacity(0.7);
        }

        emit(InfoMessageState(
          content: Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  errorIcon,
                  size: 64,
                  color: iconColor,
                ),
                const SizedBox(height: 16),
                Text(
                  errorTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppConfig.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  errorMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppConfig.tertiaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          buttonText: 'К списку устройств',
          onButtonPressed: () {
            emit(DeviceListState(_lastFoundDevices));
          },
        ));
        BackgroundOperationsManager.releaseWakeLockAfterOperation();
        return;
      }

      final listRes = await _repository
          .getReadyArchive()
          .timeout(AppConfig.readyArchiveTimeout);

      listRes.fold(
        (failure) {
          BackgroundOperationsManager.releaseWakeLockAfterOperation();
          emit(DeviceListState(_lastFoundDevices));
        },
        (fileNames) {
          final archives = fileNames
              .map((f) => ArchiveEntry(fileName: f, sizeBytes: 0))
              .toList();
          emit(ConnectedState(connectedDevice: device, archives: archives));
        },
      );
    } catch (e) {
      BackgroundOperationsManager.releaseWakeLockAfterOperation();
      emit(DeviceListState(_lastFoundDevices));
    }
  }

  Future<void> downloadArchive(ArchiveEntry entry) async {
    await BackgroundOperationsManager.ensureWakeLockForOperation();
    if (state is! ConnectedState) {
      BackgroundOperationsManager.releaseWakeLockAfterOperation();
      return;
    }

    final connectedDevice = (state as ConnectedState).connectedDevice;

    final startTime = DateTime.now();
    int? totalFileSize;

    emit(DownloadingState(
      connectedDevice: connectedDevice,
      entry: entry,
      progress: 0,
      speedLabel: '0 B/s',
      fileSize: null,
      elapsedTime: null,
    ));

    final downloadRes = await _repository.downloadFile(
      entry.fileName,
      _toEntity(connectedDevice),
      onProgress: (progress, totalBytes) {
        final elapsed =
            DateTime.now().difference(startTime).inMilliseconds / 1000.0;
        final received = (totalBytes ?? 0) * progress;
        final speed = elapsed > 0 ? received / elapsed : 0.0;
        final speedLabel = _formatSpeed(speed);
        if (totalBytes != null) totalFileSize = totalBytes;
        emit(DownloadingState(
          connectedDevice: connectedDevice,
          entry: entry,
          progress: progress,
          speedLabel: speedLabel,
          fileSize: totalFileSize,
          elapsedTime: elapsed,
        ));
      },
      onComplete: (filePath) async {
        await _handleDownloadedDb(filePath, entry, connectedDevice);
        BackgroundOperationsManager.releaseWakeLockAfterOperation();
      },
    );

    downloadRes.fold(
      (failure) {
        BackgroundOperationsManager.releaseWakeLockAfterOperation();
        emit(DeviceListState(_lastFoundDevices));
      },
      (_) {},
    );
  }

  Future<void> _handleDownloadedDb(
      String filePath, ArchiveEntry entry, Device connectedDevice) async {
    _mainData.dbPath = filePath;
    _mainData.resetOperationData();

    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: const [],
      operations: _mainData.operations.toList(),
      isLoading: true,
    ));

    final localStatus = await _mainData.awaitOperations();

    if (localStatus == OperStatus.dbError) {
      emit(_createDbErrorState('Файл не является базой данных или повреждён.'));
      return;
    }
    if (localStatus == OperStatus.filePathError) {
      emit(_createDbErrorState('Не выбран файл базы данных.'));
      return;
    }
    if (localStatus != OperStatus.ok) {
      emit(_createDbErrorState('Неизвестная ошибка при открытии базы данных.'));
      return;
    }

    for (final op in _mainData.operations) {
      await _mainData.awaitOperationPoints(op);
    }

    final netStatus = await _mainData.awaitOperationsCanSendStatus();

    final filteredOps = _mainData.operations
        .where((op) => (op.canSend == true || op.exported == true))
        .toList();
    final rows = filteredOps.map((op) {
      final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
      final wellId = op.hole;
      return TableRowData(date: dt, wellId: wellId);
    }).toList();

    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: rows,
      operations: filteredOps,
      isLoading: false,
    ));

    notifyTableChanged();

    if (netStatus != OperStatus.ok) {
      await ArchiveSyncManager.addPending(filePath);
      emit(NetErrorState(filePath));
    } else {
      // Проверяем: если нет операций для отправки, сразу помечаем архив как экспортированный
      final operationsToSend =
          _mainData.operations.where((op) => op.canSend).toList();
      if (operationsToSend.isEmpty) {
        await ArchiveSyncManager.markExported(filePath);
      }
    }
  }

  void reset() {
    _searching = false;
    BackgroundOperationsManager.releaseWakeLockAfterOperation();
    _loadPending();
  }

  bool goBack() {
    if (state is InitialSearchState) {
      // На начальном экране возвращаем false, чтобы разрешить выход из приложения
      return false;
    } else if (state is SearchingState) {
      // Останавливаем поиск и переходим к pending или начальному экрану
      _searching = false;
      _repository.cancelScan();
      BackgroundOperationsManager.releaseWakeLockAfterOperation();
      _loadPending();
      return true;
    } else if (state is TableViewState) {
      if (_lastFoundDevices.isNotEmpty) {
        emit(DeviceListState(_lastFoundDevices));
      } else {
        _loadPending();
      }
      return true;
    } else if (state is ConnectedState) {
      if (_lastFoundDevices.isNotEmpty) {
        emit(DeviceListState(_lastFoundDevices));
      } else {
        _loadPending();
      }
      return true;
    } else if (state is DeviceListState) {
      _loadPending();
      return true;
    } else if (state is SearchingStateWithDevices) {
      _searching = false;
      _repository.cancelScan();
      BackgroundOperationsManager.releaseWakeLockAfterOperation();
      _loadPending();
      return true;
    } else if (state is NetErrorState || state is InfoMessageState) {
      if (_lastFoundDevices.isNotEmpty) {
        emit(DeviceListState(_lastFoundDevices));
      } else {
        _loadPending();
      }
      return true;
    } else if (state is PendingArchivesState) {
      _loadPending();
      return true;
    } else if (state is ExportingState ||
        state is UploadingState ||
        state is RefreshingState ||
        state is DownloadingState) {
      return true;
    }

    return false;
  }

  Future<void> loadLocalArchive(String dbPath) async {
    await BackgroundOperationsManager.ensureWakeLockForOperation();
    _mainData.dbPath = dbPath;
    _mainData.resetOperationData();

    emit(TableViewState(
      connectedDevice: Device(name: 'Local', macAddress: ''),
      entry: ArchiveEntry(fileName: dbPath, sizeBytes: 0),
      rows: const [],
      operations: _mainData.operations.toList(),
      isLoading: true,
    ));

    final status = await _mainData.awaitOperations();

    if (status == OperStatus.dbError) {
      BackgroundOperationsManager.releaseWakeLockAfterOperation();
      emit(_createDbErrorState('Файл не является базой данных или повреждён.'));
      return;
    }
    if (status == OperStatus.filePathError) {
      BackgroundOperationsManager.releaseWakeLockAfterOperation();
      emit(_createDbErrorState('Не выбран файл базы данных.'));
      return;
    }
    if (status != OperStatus.ok) {
      BackgroundOperationsManager.releaseWakeLockAfterOperation();
      emit(_createDbErrorState('Неизвестная ошибка при открытии базы данных.'));
      return;
    }

    for (final op in _mainData.operations) {
      await _mainData.awaitOperationPoints(op);
    }

    final netStatus = await _mainData.awaitOperationsCanSendStatus();

    final filteredOps = _mainData.operations
        .where((op) => op.canSend == true || op.exported == true)
        .toList();
    final rows = filteredOps.map((op) {
      final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
      return TableRowData(date: dt, wellId: op.hole);
    }).toList();

    emit(TableViewState(
      connectedDevice: Device(name: 'Local', macAddress: ''),
      entry: ArchiveEntry(fileName: dbPath, sizeBytes: 0),
      rows: rows,
      operations: filteredOps,
      isLoading: false,
    ));

    notifyTableChanged();

    if (netStatus != OperStatus.ok) {
      emit(NetErrorState(dbPath));
    } else {
      final operationsToSend =
          _mainData.operations.where((op) => op.canSend).toList();
      if (operationsToSend.isEmpty) {
        await ArchiveSyncManager.markExported(dbPath);
      }
    }

    BackgroundOperationsManager.releaseWakeLockAfterOperation();
  }

  Future<void> exportSelected(
      {void Function(double progress)? onProgress,
      void Function()? onFinish}) async {
    await BackgroundOperationsManager.ensureWakeLockForOperation();
    if (state is! TableViewState) {
      BackgroundOperationsManager.releaseWakeLockAfterOperation();
      return;
    }

    final prevState = state as TableViewState;
    final connectedDevice = prevState.connectedDevice;
    final entry = prevState.entry;
    final rows = prevState.rows;

    final selected =
        _mainData.operations.where((op) => op.selected && op.canSend).toList();

    if (selected.isEmpty) {
      emit(TableViewState(
        connectedDevice: connectedDevice,
        entry: entry,
        rows: rows,
        operations: _mainData.operations.toList(),
        isLoading: false,
      ));
      BackgroundOperationsManager.releaseWakeLockAfterOperation();
      return;
    }

    bool hasSuccess = false;

    final archiveFileName = _mainData.dbPath.split('/').last;
    final exportedOps = <int>[];

    final totalPoints =
        selected.fold<int>(0, (sum, op) => sum + op.points.length);
    int exportedPoints = 0;

    emit(ExportingState(0, entry: entry, connectedDevice: connectedDevice));

    List<Operation> currentOps = _mainData.operations
        .map((op) => Operation(
              dt: op.dt,
              dtStop: op.dtStop,
              maxP: op.maxP,
              idOrg: op.idOrg,
              workType: op.workType,
              ngdu: op.ngdu,
              field: op.field,
              section: op.section,
              bush: op.bush,
              hole: op.hole,
              brigade: op.brigade,
              lat: op.lat,
              lon: op.lon,
              equipment: op.equipment,
              pCnt: op.pCnt,
              points: op.points,
            )
              ..selected = op.selected
              ..canSend = op.canSend
              ..checkError = op.checkError
              ..exported = op.exported
              ..unavailable = op.unavailable
              ..errorCode = op.errorCode)
        .toList();

    for (int i = 0; i < selected.length; i++) {
      final op = selected[i];

      emit(ExportingState(
        totalPoints == 0 ? 0.0 : exportedPoints / totalPoints,
        entry: entry,
        connectedDevice: connectedDevice,
        currentExportingOperationDt: op.dt,
      ));

      final code = await _mainData.awaitSendingOperation(op);
      final idx = currentOps.indexWhere((o) => o.dt == op.dt);
      if (idx != -1) {
        if (code == 200) {
          hasSuccess = true;
          currentOps[idx] = Operation(
            dt: op.dt,
            dtStop: op.dtStop,
            maxP: op.maxP,
            idOrg: op.idOrg,
            workType: op.workType,
            ngdu: op.ngdu,
            field: op.field,
            section: op.section,
            bush: op.bush,
            hole: op.hole,
            brigade: op.brigade,
            lat: op.lat,
            lon: op.lon,
            equipment: op.equipment,
            pCnt: op.pCnt,
            points: op.points,
          )
            ..selected = false
            ..canSend = false
            ..checkError = false
            ..exported = true
            ..unavailable = false
            ..errorCode = 0;
          exportedOps.add(op.dt);
          await ExportStatusManager.addExportedOp(archiveFileName, op.dt);

          // Обновляем операцию в MainData сразу же
          final mainDataIdx =
              _mainData.operations.indexWhere((o) => o.dt == op.dt);
          if (mainDataIdx != -1) {
            _mainData.operations[mainDataIdx].exported = true;
            _mainData.operations[mainDataIdx].selected = false;
            _mainData.operations[mainDataIdx].canSend = false;
            _mainData.operations[mainDataIdx].checkError = false;
            _mainData.operations[mainDataIdx].unavailable = false;
            _mainData.operations[mainDataIdx].errorCode = 0;
          }
        } else {
          currentOps[idx] = Operation(
            dt: op.dt,
            dtStop: op.dtStop,
            maxP: op.maxP,
            idOrg: op.idOrg,
            workType: op.workType,
            ngdu: op.ngdu,
            field: op.field,
            section: op.section,
            bush: op.bush,
            hole: op.hole,
            brigade: op.brigade,
            lat: op.lat,
            lon: op.lon,
            equipment: op.equipment,
            pCnt: op.pCnt,
            points: op.points,
          )
            ..selected = op.selected
            ..canSend = op.canSend
            ..checkError = true
            ..exported = false
            ..unavailable = false
            ..errorCode = code;

          // Обновляем операцию в MainData сразу же
          final mainDataIdx =
              _mainData.operations.indexWhere((o) => o.dt == op.dt);
          if (mainDataIdx != -1) {
            _mainData.operations[mainDataIdx].checkError = true;
            _mainData.operations[mainDataIdx].exported = false;
            _mainData.operations[mainDataIdx].unavailable = false;
            _mainData.operations[mainDataIdx].errorCode = code;
          }
        }
      }
      exportedPoints += op.points.length;
      final prog = totalPoints == 0 ? 1.0 : exportedPoints / totalPoints;

      // Эмитим состояние с обновленным прогрессом чтобы UI обновился
      emit(ExportingState(
        prog,
        entry: entry,
        connectedDevice: connectedDevice,
        currentExportingOperationDt: op.dt,
      ));
      onProgress?.call(prog);

      // Небольшая задержка чтобы UI успел обновиться
      await Future.delayed(const Duration(milliseconds: 50));
    }
    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: rows,
      operations: currentOps,
      isLoading: false,
      disabled: false,
    ));
    onProgress?.call(0);
    _mainData.operations
      ..clear()
      ..addAll(currentOps);

    final allOpDts = currentOps.map((op) => op.dt).toList();
    final allExported = currentOps.every((op) => !op.canSend);
    if (allExported) {
      await ArchiveSyncManager.markExported(_mainData.dbPath);
      await ExportStatusManager.setArchiveStatus(
          archiveFileName, 'exported', allOpDts);
    } else {
      await ExportStatusManager.setArchiveStatus(
          archiveFileName, 'partial', allOpDts);
    }

    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: rows,
      operations: currentOps,
      isLoading: false,
    ));
    notifyTableChanged();

    BackgroundOperationsManager.releaseWakeLockAfterOperation();
    onFinish?.call();
  }

  void notifyTableChanged() {
    if (state is TableViewState) {
      final s = state as TableViewState;
      final filteredOps = _mainData.operations
          .where((op) => op.canSend == true || op.exported == true)
          .toList();
      final rows = filteredOps.map((op) {
        final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
        return TableRowData(date: dt, wellId: op.hole);
      }).toList();
      emit(TableViewState(
        connectedDevice: s.connectedDevice,
        entry: s.entry,
        rows: rows,
        operations: filteredOps,
        isLoading: false,
      ));
    }
  }

  void updateOperations(List<Operation> ops) {
    _mainData.operations
      ..clear()
      ..addAll(ops);
    if (state is TableViewState) {
      final s = state as TableViewState;
      final filteredOps =
          ops.where((op) => op.canSend == true || op.exported == true).toList();
      final rows = filteredOps.map((op) {
        final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
        return TableRowData(date: dt, wellId: op.hole);
      }).toList();
      emit(TableViewState(
        connectedDevice: s.connectedDevice,
        entry: s.entry,
        rows: rows,
        operations: filteredOps,
        isLoading: false,
      ));
    }
  }

  void stopScanning() {
    _searching = false;
    _repository.cancelScan();
    BackgroundOperationsManager.releaseWakeLockAfterOperation();
    emit(DeviceListState(List<Device>.from(_lastFoundDevices)));
  }

  Future<void> deletePendingArchive(String path) async {
    await ArchiveSyncManager.deletePending(path);
    await _loadPending();
  }

  /// Создает InfoMessageState для ошибок базы данных с кнопкой отправки логов
  InfoMessageState _createDbErrorState(String errorMessage) {
    return InfoMessageState(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppConfig.errorColor, size: 48),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: const TextStyle(color: AppConfig.errorColor, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SendLogsButton(
            buttonText: 'Отправить логи',
            icon: Icons.bug_report,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          ),
        ],
      ),
      onButtonPressed: reset,
      buttonText: 'Назад',
    );
  }
}
