import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/data/main_data.dart';
import 'device_flow_state.dart';
import '../models/device.dart';
import '../models/archive_entry.dart';
import 'package:bluetooth_per/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:bluetooth_per/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:bluetooth_per/core/utils/archive_sync_manager.dart';
import 'package:bluetooth_per/core/utils/export_status_manager.dart'
    hide ExportStatusManager;
import 'package:bluetooth_per/core/data/source/operation.dart';

class DeviceFlowCubit extends Cubit<DeviceFlowState> {
  final BluetoothRepository _repository;
  final MainData _mainData;
  final List<Device> _lastFoundDevices = [];
  bool _searching = false;

  DeviceFlowCubit(this._repository, this._mainData)
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

  // Helper: convert bytes/sec to human-readable label.
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

  // Start scanning for Bluetooth devices using the repository.
  Future<void> startScanning() async {
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
        _searching = false;
        emit(const InitialSearchState());
      },
      (entities) {
        _searching = false;
        final devices = entities.map(_toUi).toList();
        _lastFoundDevices.clear();
        _lastFoundDevices.addAll(devices);
        if (devices.isEmpty) {
          emit(const InitialSearchState());
        } else {
          emit(DeviceListState(devices));
        }
      },
    );
  }

  // Connect to a selected device and request archive update.
  Future<void> connectToDevice(Device device) async {
    _searching = false;
    _repository.cancelScan();
    print(
        '[DeviceFlowCubit] connectToDevice: [36m${device.name}[0m ([36m${device.macAddress}[0m)');
    emit(UploadingState(device));

    final connectRes = await _repository.connectToDevice(_toEntity(device));

    bool connected = false;
    connectRes.fold(
      (failure) {
        print('[DeviceFlowCubit] connectToDevice: failure=$failure');
        emit(const InitialSearchState());
      },
      (_) {
        print('[DeviceFlowCubit] connectToDevice: success');
        connected = true;
      },
    );

    if (!connected) return;

    // Listen for archive-update stream.
    await for (final status in _repository.requestArchiveUpdate()) {
      print('[DeviceFlowCubit] connectToDevice: archive update status=$status');
      if (status == 'ARCHIVE_UPDATING') {
        emit(RefreshingState(device));
      } else if (status == 'ARCHIVE_READY') {
        break;
      }
    }

    // After archive ready, query file list.
    final listRes = await _repository.getFileList();

    listRes.fold(
      (failure) {
        print(
            '[DeviceFlowCubit] connectToDevice: getFileList failure=$failure');
        emit(const InitialSearchState());
      },
      (fileNames) {
        final archives = fileNames
            .map((f) => ArchiveEntry(fileName: f, sizeBytes: 0))
            .toList();
        print(
            '[DeviceFlowCubit] connectToDevice: got ${archives.length} archives');
        emit(ConnectedState(connectedDevice: device, archives: archives));
      },
    );
  }

  // Download selected archive using repository and update UI with progress.
  Future<void> downloadArchive(ArchiveEntry entry) async {
    print('[DeviceFlowCubit] downloadArchive: ${entry.fileName}');
    if (state is! ConnectedState) {
      print(
          '[DeviceFlowCubit] downloadArchive: not in ConnectedState, current=$state');
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
        print(
            '[DeviceFlowCubit] downloadArchive: onComplete filePath=$filePath');
        await _handleDownloadedDb(filePath, entry, connectedDevice);
      },
    );

    downloadRes.fold(
      (failure) {
        print('[DeviceFlowCubit] downloadArchive: failure=$failure');
        emit(const InitialSearchState());
      },
      (_) {},
    );
  }

  // Process downloaded SQLite database and show table.
  Future<void> _handleDownloadedDb(
      String filePath, ArchiveEntry entry, Device connectedDevice) async {
    print('[DeviceFlowCubit] _handleDownloadedDb: filePath=$filePath');
    _mainData.dbPath = filePath;
    _mainData.resetOperationData();

    // Сразу показываем таблицу с isLoading=true
    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: const [],
      operations: _mainData.operations.toList(),
      isLoading: true,
    ));

    final localStatus = await _mainData.awaitOperations();
    print(
        '[DeviceFlowCubit] _handleDownloadedDb: awaitOperations status = $localStatus');

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
        .where((op) => op.canSend == true || op.exported == true)
        .toList();
    final rows = filteredOps.map((op) {
      final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
      final wellId = op.hole;
      return TableRowData(date: dt, wellId: wellId);
    }).toList();

    print(
        '[DeviceFlowCubit] _handleDownloadedDb: emitting TableViewState with \x1b[32m${rows.length}\x1b[0m rows');
    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: rows,
      operations: filteredOps,
      isLoading: false,
    ));

    // Обновляем таблицу после синхронизации с сервером
    notifyTableChanged();

    if (netStatus != OperStatus.ok) {
      // Нет сети – помечаем архив как «ожидающий» и показываем ошибку, но таблица уже показана
      print(
          '[DeviceFlowCubit] _handleDownloadedDb: netStatus not ok, marking as pending');
      await ArchiveSyncManager.addPending(filePath);
      emit(NetErrorState(filePath));
    }
  }

  // Reset to initial.
  void reset() {
    print('[DeviceFlowCubit] reset called');
    _loadPending();
  }

  /// Загружает локальный архив без подключения к устройству.
  Future<void> loadLocalArchive(String dbPath) async {
    _mainData.dbPath = dbPath;
    _mainData.resetOperationData();

    // Сразу показываем таблицу с isLoading=true
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

    // Обновляем таблицу после синхронизации с сервером
    notifyTableChanged();

    if (netStatus != OperStatus.ok) {
      emit(NetErrorState(dbPath));
    }
  }

  /// Экспорт отмеченных операций на сервер соStatus
  Future<void> exportSelected(
      {void Function(double progress)? onProgress,
      void Function()? onFinish}) async {
    if (state is! TableViewState) {
      print('[exportSelected] Not in TableViewState, current: $state');
      return;
    }

    final prevState = state as TableViewState;
    final connectedDevice = prevState.connectedDevice;
    final entry = prevState.entry;
    final rows = prevState.rows;

    final selected =
        _mainData.operations.where((op) => op.selected && op.canSend).toList();

/*     for (final op in selected) {
      await _mainData.awaitOperationPoints(op);
    } */

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

    int done = 0;
    bool hasSuccess = false;
    print('[exportSelected] Start export loop');

    final archiveFileName = _mainData.dbPath.split('/').last;
    final exportedOps = <int>[];

    // --- Новый прогресс по точкам операций ---
    final totalPoints =
        selected.fold<int>(0, (sum, op) => sum + op.points.length);
    int exportedPoints = 0;
    print('[exportSelected] totalPoints = '
        '\x1b[32m$totalPoints\u001b[0m');

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
              ..checkError = false)
        .toList();

    for (int i = 0; i < selected.length; i++) {
      final op = selected[i];
      final code = await _mainData.awaitSendingOperation(op);
      final idx = currentOps.indexWhere((o) => o.dt == op.dt);
      if (idx != -1) {
        if (code == 200) {
          hasSuccess = true;
          done++;
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
      ));
      if (onProgress != null) onProgress(prog);
      // Обновляем таблицу после каждой операции, но блокируем UI
      emit(TableViewState(
        connectedDevice: connectedDevice,
        entry: entry,
        rows: rows,
        operations: currentOps,
        isLoading: false,
        disabled: true,
      ));
    }
    // После завершения экспорта — разблокируем UI
    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: rows,
      operations: currentOps,
      isLoading: false,
      disabled: false,
    ));
    onProgress!(0);
    // После экспорта обновляем основной список операций
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

    // Сбросить прогресс
    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: rows,
      operations: currentOps,
      isLoading: false,
    ));
    // Обновляем таблицу после экспорта
    notifyTableChanged();

    if (onFinish != null) onFinish();
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
    _repository.cancelScan();
    emit(DeviceListState(List<Device>.from(_lastFoundDevices)));
  }
}
