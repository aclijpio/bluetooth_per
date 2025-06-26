import 'package:flutter_bloc/flutter_bloc.dart';
import 'device_flow_state.dart';
import '../models/device.dart';
import '../models/archive_entry.dart';

class DeviceFlowCubit extends Cubit<DeviceFlowState> {
  DeviceFlowCubit() : super(const InitialSearchState());

  // Simulate starting scanning.
  void startScanning() async {
    emit(const SearchingState());

    // TODO: Replace this with real bluetooth scan.
    await Future.delayed(const Duration(seconds: 2));

    final mockDevices = [
      const Device(name: 'A765CM116', macAddress: 'F8:99:B2:6F:95:FD'),
      const Device(name: 'O765OO116', macAddress: 'C8:21:B2:1F:11:AA'),
      const Device(name: 'M766CC116', macAddress: '00:11:22:33:44:55'),
    ];

    if (mockDevices.length == 1) {
      connectToDevice(mockDevices.first);
    } else {
      emit(DeviceListState(mockDevices));
    }
  }

  // User selects a device from list.
  void connectToDevice(Device device) async {
    emit(UploadingState(device));

    // simulate upload to server
    await Future.delayed(const Duration(seconds: 2));
    emit(RefreshingState(device));

    // simulate server refreshing
    await Future.delayed(const Duration(seconds: 3));

    final archives = [
      const ArchiveEntry(fileName: 'C66MM89.db', sizeBytes: 1024 * 1024 * 50),
    ];
    emit(ConnectedState(connectedDevice: device, archives: archives));
  }

  // User taps download archive.
  void downloadArchive(ArchiveEntry entry) async {
    // Preserve connected device reference before we start emitting DownloadingState
    final connectedDevice = (state as ConnectedState).connectedDevice;

    const totalParts = 100;
    for (int i = 0; i <= totalParts; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      emit(
        DownloadingState(
          connectedDevice: connectedDevice,
          entry: entry,
          progress: i / totalParts,
          speedLabel: '1 Mb/s',
        ),
      );
    }
    // After finishing download, show table.
    showTable(entry, connectedDevice);
  }

  void showTable(ArchiveEntry entry, Device connectedDevice) {
    final rows = List<TableRowData>.generate(
      10,
      (index) => TableRowData(
        date: DateTime.now().subtract(Duration(days: index)),
        wellId: '6547767',
      ),
    );
    emit(
      TableViewState(
        connectedDevice: connectedDevice,
        entry: entry,
        rows: rows,
      ),
    );
  }

  // Reset to initial.
  void reset() => emit(const InitialSearchState());
}
