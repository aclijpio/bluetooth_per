import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'bluetooth_bloc.dart';
import 'bluetooth_state.dart';
import 'device_flow_state.dart';
import '../../domain/entities/bluetooth_device.dart';
import '../models/device.dart';
import '../models/archive_entry.dart';
import 'bluetooth_event.dart';

/// Кубит-«адаптер»: переводит реальные состояния [BluetoothBloc]
/// в экранные состояния [DeviceFlowState], чтобы переиспользовать
/// уже нарисованный UI (flow_screen.dart) без симуляции.
class DeviceFlowCubit extends Cubit<DeviceFlowState> {
  DeviceFlowCubit({required this.bluetoothBloc}) : super(const InitialSearchState()) {
    _sub = bluetoothBloc.stream.listen(_handleBtState);
    // учтём стартовое состояние
    _handleBtState(bluetoothBloc.state);
  }

  final BluetoothBloc bluetoothBloc;
  late final StreamSubscription _sub;
  Device? _currentDevice;

  // ───────── UI actions ──────────
  void startScanning() {
    bluetoothBloc.add(const StartScanning());
  }

  void connectToDevice(Device device) {
    final entity = BluetoothDeviceEntity(address: device.macAddress, name: device.name);
    bluetoothBloc.add(ConnectToDevice(entity));
  }

  void downloadArchive(ArchiveEntry entry) {
    bluetoothBloc.add(DownloadFile(entry.fileName));
  }

  // ───────── mapping logic ──────────
  void _handleBtState(BluetoothState s) {
    if (s is BluetoothInitial || s is BluetoothDisabled) {
      emit(const InitialSearchState());
    } else if (s is BluetoothLoading) {
      emit(const SearchingState());
    } else if (s is BluetoothScanning) {
      final devices = s.devices
          .map((e) => Device(name: e.name ?? 'Unknown', macAddress: e.address))
          .toList();
      emit(DeviceListState(devices));
    } else if (s is ArchiveUpdatingState) {
      final dev = Device(name: s.device.name ?? 'Unknown', macAddress: s.device.address);
      _currentDevice = dev;
      emit(RefreshingState(dev));
    } else if (s is ArchiveReadyState || s is BluetoothConnected) {
      final bc = (s is BluetoothConnected) ? s : (s as ArchiveReadyState);
      final dev = Device(name: bc.device.name ?? 'Unknown', macAddress: bc.device.address);
      _currentDevice = dev;
      final archives = bc.fileList
          .map((f) => ArchiveEntry(fileName: f, sizeBytes: 0))
          .toList();
      emit(ConnectedState(connectedDevice: dev, archives: archives));
    } else if (s is FileDownloading) {
      final dev = _currentDevice ?? Device(name: '', macAddress: '');
      final entry = ArchiveEntry(fileName: s.fileName, sizeBytes: 0);
      emit(DownloadingState(
        connectedDevice: dev,
        entry: entry,
        progress: s.progress,
        speedLabel: '',
      ));
    } else if (s is FileDownloaded) {
      final dev = _currentDevice ?? Device(name: '', macAddress: '');
      final entry = ArchiveEntry(fileName: s.fileName, sizeBytes: 0);
      _showTable(entry, dev);
    } else if (s is BluetoothError) {
      // На экране покажем как Initial с возможностью повторить
      emit(const InitialSearchState());
    }
  }

  void _showTable(ArchiveEntry entry, Device connectedDevice) {
    final rows = List<TableRowData>.generate(
      10,
      (index) => TableRowData(
        date: DateTime.now().subtract(Duration(days: index)),
        wellId: '---',
      ),
    );
    emit(TableViewState(connectedDevice: connectedDevice, entry: entry, rows: rows));
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}

