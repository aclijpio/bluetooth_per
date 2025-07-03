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
    print('[DeviceFlowCubit] startScanning called');
    emit(const SearchingState());

    final result = await _repository.scanForDevices();

    result.fold(
      (failure) {
        print('[DeviceFlowCubit] startScanning: failure=$failure');
        emit(const InitialSearchState());
      },
      (entities) {
        final devices = entities.map(_toUi).toList();
        print(
            '[DeviceFlowCubit] startScanning: found ${devices.length} devices');
        if (devices.isEmpty) {
          emit(const InitialSearchState());
        } else {
          // Всегда показываем список, даже если устройство одно
          emit(DeviceListState(devices));
        }
      },
    );
  }

  // Connect to a selected device and request archive update.
  Future<void> connectToDevice(Device device) async {
    print(
        '[DeviceFlowCubit] connectToDevice: ${device.name} (${device.macAddress})');
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

    if (localStatus != OperStatus.ok) {
      print(
          '[DeviceFlowCubit] _handleDownloadedDb: localStatus not ok, returning to InitialSearchState');
      emit(const InitialSearchState());
      return;
    }

    // Проверяем связь с сервером – определяем canSend.
    final netStatus = await _mainData.awaitOperationsCanSendStatus();
    print(
        '[DeviceFlowCubit] _handleDownloadedDb: awaitOperationsCanSendStatus = $netStatus');

    if (netStatus != OperStatus.ok) {
      // Нет сети – помечаем архив как «ожидающий» и показываем список.
      print(
          '[DeviceFlowCubit] _handleDownloadedDb: netStatus not ok, marking as pending');
      await ArchiveSyncManager.addPending(filePath);

      emit(NetErrorState(filePath));
      return;
    }

    final rows = _mainData.operations.map((op) {
      final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
      final wellId = op.hole;
      return TableRowData(date: dt, wellId: wellId);
    }).toList();

    print(
        '[DeviceFlowCubit] _handleDownloadedDb: emitting TableViewState with ${rows.length} rows');
    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: rows,
      operations: _mainData.operations.toList(),
      isLoading: false,
    ));
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
    if (status != OperStatus.ok) {
      emit(const InitialSearchState());
      return;
    }

    await _mainData.awaitOperationsCanSendStatus();

    final rows = _mainData.operations.map((op) {
      final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
      return TableRowData(date: dt, wellId: op.hole);
    }).toList();

    emit(TableViewState(
      connectedDevice: Device(name: 'Local', macAddress: ''),
      entry: ArchiveEntry(fileName: dbPath, sizeBytes: 0),
      rows: rows,
      operations: _mainData.operations.toList(),
      isLoading: false,
    ));
  }

  /// Экспорт отмеченных операций на сервер соStatus
  Future<void> exportSelected() async {
    if (state is! TableViewState) {
      print('[exportSelected] Not in TableViewState, current: $state');
      return;
    }

    final selected =
        _mainData.operations.where((op) => op.selected && op.canSend).toList();
    print('[exportSelected] selected count: ${selected.length}');

    if (selected.isEmpty) {
      print('[exportSelected] No operations selected for export');
      emit(TableViewState(
        connectedDevice: Device(name: 'Local', macAddress: ''),
        entry: ArchiveEntry(fileName: _mainData.dbPath, sizeBytes: 0),
        rows: _mainData.operations.map((o) {
          final dt = DateTime.fromMillisecondsSinceEpoch(o.dt * 1000);
          return TableRowData(date: dt, wellId: o.hole);
        }).toList(),
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

    // Копируем операции для накопления статусов
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

    for (final op in selected) {
      print(
          '[exportSelected] Exporting operation dt=\u001b[33m${op.dt}\u001b[0m');
      final code =
          await _mainData.awaitSendingOperationWithProgress(op, (progress) {});
      print('[exportSelected] Result for dt=${op.dt}: $code');
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
            ..checkError = false;
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
            ..checkError = true;
        }
      }
    }

    // После экспорта обновляем основной список операций
    _mainData.operations
      ..clear()
      ..addAll(currentOps);

    print('[exportSelected] All operations exported, marking archive exported');
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
      connectedDevice: (state as TableViewState).connectedDevice,
      entry: (state as TableViewState).entry,
      rows: (state as TableViewState).rows,
      operations: currentOps,
      isLoading: false,
    ));
  }

  void notifyTableChanged() {
    if (state is TableViewState) {
      final s = state as TableViewState;
      final rows = _mainData.operations.map((op) {
        final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
        return TableRowData(date: dt, wellId: op.hole);
      }).toList();
      emit(TableViewState(
        connectedDevice: s.connectedDevice,
        entry: s.entry,
        rows: rows,
        operations: _mainData.operations.toList(),
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
      final rows = ops.map((op) {
        final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
        return TableRowData(date: dt, wellId: op.hole);
      }).toList();
      emit(TableViewState(
        connectedDevice: s.connectedDevice,
        entry: s.entry,
        rows: rows,
        operations: ops,
        isLoading: false,
      ));
    }
  }
}
