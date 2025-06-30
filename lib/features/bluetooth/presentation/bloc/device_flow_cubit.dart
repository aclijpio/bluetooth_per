import 'package:flutter_bloc/flutter_bloc.dart';
import 'device_flow_state.dart';
import '../models/device.dart';
import '../models/archive_entry.dart';
import 'package:bluetooth_per/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:bluetooth_per/features/web/data/repositories/main_data.dart';
import 'package:bluetooth_per/features/bluetooth/domain/entities/bluetooth_device.dart';

class DeviceFlowCubit extends Cubit<DeviceFlowState> {
  final BluetoothRepository _repository;
  final MainData _mainData;

  DeviceFlowCubit(this._repository, this._mainData)
      : super(const InitialSearchState());

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
    emit(const SearchingState());

    final result = await _repository.scanForDevices();

    result.fold(
      (failure) => emit(const InitialSearchState()),
      (entities) {
        final devices = entities.map(_toUi).toList();

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
    emit(UploadingState(device));

    final connectRes = await _repository.connectToDevice(_toEntity(device));

    bool connected = false;
    connectRes.fold(
      (failure) => emit(const InitialSearchState()),
      (_) => connected = true,
    );

    if (!connected) return;

    // Listen for archive-update stream.
    await for (final status in _repository.requestArchiveUpdate()) {
      if (status == 'ARCHIVE_UPDATING') {
        emit(RefreshingState(device));
      } else if (status == 'ARCHIVE_READY') {
        break;
      }
    }

    // After archive ready, query file list.
    final listRes = await _repository.getFileList();

    listRes.fold(
      (failure) => emit(const InitialSearchState()),
      (fileNames) {
        final archives = fileNames
            .map((f) => ArchiveEntry(fileName: f, sizeBytes: 0))
            .toList();
        emit(ConnectedState(connectedDevice: device, archives: archives));
      },
    );
  }

  // Download selected archive using repository and update UI with progress.
  Future<void> downloadArchive(ArchiveEntry entry) async {
    if (state is! ConnectedState) return;

    final connectedDevice = (state as ConnectedState).connectedDevice;

    final startTime = DateTime.now();

    emit(DownloadingState(
      connectedDevice: connectedDevice,
      entry: entry,
      progress: 0,
      speedLabel: '0 B/s',
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
        emit(DownloadingState(
          connectedDevice: connectedDevice,
          entry: entry,
          progress: progress,
          speedLabel: speedLabel,
        ));
      },
      onComplete: (filePath) async {
        await _handleDownloadedDb(filePath, entry, connectedDevice);
      },
    );

    downloadRes.fold(
      (failure) => emit(const InitialSearchState()),
      (_) {},
    );
  }

  // Process downloaded SQLite database and show table.
  Future<void> _handleDownloadedDb(
      String filePath, ArchiveEntry entry, Device connectedDevice) async {
    _mainData.dbPath = filePath;
    _mainData.resetOperationData();

    final status = await _mainData.awaitOperations();
    if (status != OperStatus.ok) {
      emit(const InitialSearchState());
      return;
    }

    final rows = _mainData.operations.map((op) {
      final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
      final wellId = op.hole;
      return TableRowData(date: dt, wellId: wellId);
    }).toList();

    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: rows,
    ));
  }

  // Reset to initial.
  void reset() => emit(const InitialSearchState());
}
