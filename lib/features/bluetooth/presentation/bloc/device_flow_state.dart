import 'package:equatable/equatable.dart';
import '../models/device.dart';
import '../models/archive_entry.dart';

// Base class for all states.
abstract class DeviceFlowState extends Equatable {
  const DeviceFlowState();

  @override
  List<Object?> get props => [];
}

// 1) Initial screen where user can start searching for devices.
class InitialSearchState extends DeviceFlowState {
  const InitialSearchState();
}

// 2) Search in progress screen (showing spinner).
class SearchingState extends DeviceFlowState {
  const SearchingState();
}

// 3) List of discovered devices. If the list has exactly one item, the cubit can skip this state.
class DeviceListState extends DeviceFlowState {
  final List<Device> devices;
  const DeviceListState(this.devices);

  @override
  List<Object?> get props => [devices];
}

// 4) Connected to device and downloading archive list.
class ConnectedState extends DeviceFlowState {
  final Device connectedDevice;
  final List<ArchiveEntry> archives;
  const ConnectedState({required this.connectedDevice, required this.archives});

  @override
  List<Object?> get props => [connectedDevice, archives];
}

// 5) Download in progress for a single archive.
class DownloadingState extends DeviceFlowState {
  final Device connectedDevice;
  final ArchiveEntry entry;

  /// Progress from 0.0 .. 1.0
  final double progress;

  /// bytes per second or other units.
  final String speedLabel;
  const DownloadingState({
    required this.connectedDevice,
    required this.entry,
    required this.progress,
    required this.speedLabel,
  });

  @override
  List<Object?> get props => [connectedDevice, entry, progress, speedLabel];
}

// 6) Table view with downloaded data (web-service like table).
class TableViewState extends DeviceFlowState {
  final Device connectedDevice;
  final ArchiveEntry entry;
  final List<TableRowData> rows;
  const TableViewState({
    required this.connectedDevice,
    required this.entry,
    required this.rows,
  });

  @override
  List<Object?> get props => [connectedDevice, entry, rows];
}

// Helper model for table rows.
class TableRowData extends Equatable {
  final DateTime date;
  final String wellId;
  const TableRowData({required this.date, required this.wellId});

  @override
  List<Object?> get props => [date, wellId];
}

// uploading db to server
class UploadingState extends DeviceFlowState {
  final Device connectedDevice;
  const UploadingState(this.connectedDevice);

  @override
  List<Object?> get props => [connectedDevice];
}

// server refreshing archive
class RefreshingState extends DeviceFlowState {
  final Device connectedDevice;
  const RefreshingState(this.connectedDevice);

  @override
  List<Object?> get props => [connectedDevice];
}
