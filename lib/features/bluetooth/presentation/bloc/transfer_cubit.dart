import 'package:bluetooth_per/core/config.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import 'package:bluetooth_per/core/utils/archive_sync_manager.dart';
import 'package:bluetooth_per/core/utils/export_status_manager.dart';
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
    print('[TransferCubit] Начинаем сканирование устройств...');
    _searching = true;
    emit(const SearchingState());

    _lastFoundDevices.clear();
    final result = await _repository.scanForDevices(
      onDeviceFound: (entity) {
        print(
            '[TransferCubit] Найдено устройство: ${entity.name} (${entity.address})');
        if (!_searching) return;
        final device = _toUi(entity);
        if (!_lastFoundDevices.any((d) => d.macAddress == device.macAddress)) {
          _lastFoundDevices.add(device);
          print(
              '[TransferCubit] Добавлено устройство в список: ${device.name}');
          emit(SearchingStateWithDevices(List<Device>.from(_lastFoundDevices)));
        }
      },
    );

    result.fold(
      (failure) {
        print('[TransferCubit] Ошибка сканирования: ${failure.message}');
        if (!_searching || _isActiveState()) return;
        _searching = false;

        if (failure.message == 'BLUETOOTH_DISABLED') {
          print('[TransferCubit] Bluetooth выключен');
          emit(const BluetoothDisabledState());
        } else if (failure.message.contains('разрешение')) {
          print('[TransferCubit] Проблема с разрешениями: ${failure.message}');
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
            onButtonPressed: () {
              _loadPending();
            },
          ));
        } else {
          print(
              '[TransferCubit] Другая ошибка сканирования: ${failure.message}');
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
            onButtonPressed: () {
              _loadPending();
            },
          ));
        }
      },
      (entities) {
        print(
            '[TransferCubit] Сканирование завершено. Найдено ${entities.length} устройств');
        if (!_searching || _isActiveState()) return;
        final devices = entities.map(_toUi).toList();
        _lastFoundDevices.clear();
        _lastFoundDevices.addAll(devices);
        _searching = false;
        if (devices.isEmpty) {
          print(
              '[TransferCubit] Устройства не найдены, показываем pending архивы');
          _loadPending();
        } else {
          print('[TransferCubit] Показываем список найденных устройств');
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
        state is DbErrorState ||
        state is BluetoothDisabledState;
  }

  Future<void> connectToDevice(Device device) async {
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
          emit(DeviceListState(_lastFoundDevices));
        },
        (_) {
          connected = true;
        },
      );

      if (!connected) return;

      try {
        await for (final status in _repository.requestArchiveUpdate().timeout(
          AppConfig.deviceFlowTimeout,
          onTimeout: (sink) {
            sink.close();
          },
        )) {
          if (status == 'ARCHIVE_UPDATING') {
            emit(RefreshingState(device));
          } else if (status == 'ARCHIVE_READY') {
            break;
          }
        }
      } catch (e) {
        emit(InfoMessageState(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bluetooth_disabled,
                size: 64,
                color: Colors.orange.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              const Text(
                'Нет ответа от Bluetooth сервера',
                style: TextStyle(
                  fontSize: 18,
                  color: AppConfig.secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Проверьте, запущен ли ТМС на подключаемом устройстве',
                style: TextStyle(
                  fontSize: 14,
                  color: AppConfig.tertiaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          onButtonPressed: () {
            emit(DeviceListState(_lastFoundDevices));
          },
        ));
        return;
      }

      final listRes = await _repository
          .getReadyArchive()
          .timeout(AppConfig.readyArchiveTimeout);

      listRes.fold(
        (failure) {
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
      emit(DeviceListState(_lastFoundDevices));
    }
  }

  Future<void> downloadArchive(ArchiveEntry entry) async {
    if (state is! ConnectedState) {
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
      },
    );

    downloadRes.fold(
      (failure) {
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
      emit(const DbErrorState('Файл не является базой данных или повреждён.'));
      return;
    }
    if (localStatus == OperStatus.filePathError) {
      emit(const DbErrorState('Не выбран файл базы данных.'));
      return;
    }
    if (localStatus != OperStatus.ok) {
      emit(const DbErrorState('Неизвестная ошибка при открытии базы данных.'));
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
    }
  }

  void reset() {
    _searching = false;
    _loadPending();
  }

  Future<void> loadLocalArchive(String dbPath) async {
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
      emit(const DbErrorState('Файл не является базой данных или повреждён.'));
      return;
    }
    if (status == OperStatus.filePathError) {
      emit(const DbErrorState('Не выбран файл базы данных.'));
      return;
    }
    if (status != OperStatus.ok) {
      emit(const DbErrorState('Неизвестная ошибка при открытии базы данных.'));
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
    }
  }

  Future<void> exportSelected(
      {void Function(double progress)? onProgress,
      void Function()? onFinish}) async {
    if (state is! TableViewState) {
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
        }
      }
      exportedPoints += op.points.length;
      final prog = totalPoints == 0 ? 1.0 : exportedPoints / totalPoints;
      emit(ExportingState(
        prog,
        entry: entry,
        connectedDevice: connectedDevice,
        currentExportingOperationDt: op.dt,
      ));
      onProgress?.call(prog);
      emit(TableViewState(
        connectedDevice: connectedDevice,
        entry: entry,
        rows: rows,
        operations: currentOps,
        isLoading: false,
        disabled: true,
      ));
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
    emit(DeviceListState(List<Device>.from(_lastFoundDevices)));
  }

  Future<void> deletePendingArchive(String path) async {
    await ArchiveSyncManager.deletePending(path);
    await _loadPending();
  }
}
