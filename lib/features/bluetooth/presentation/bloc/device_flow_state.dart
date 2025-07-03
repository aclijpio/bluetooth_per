import 'package:equatable/equatable.dart';
import '../models/device.dart';
import '../models/archive_entry.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';

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

class PendingArchivesState extends DeviceFlowState {
  final List<String> dbPaths;
  const PendingArchivesState(this.dbPaths);

  @override
  List<Object?> get props => [dbPaths];
}

class SearchingState extends DeviceFlowState {
  const SearchingState();
}

class DeviceListState extends DeviceFlowState {
  final List<Device> devices;
  const DeviceListState(this.devices);

  @override
  List<Object?> get props => [devices];
}

class ConnectedState extends DeviceFlowState {
  final Device connectedDevice;
  final List<ArchiveEntry> archives;
  const ConnectedState({required this.connectedDevice, required this.archives});

  @override
  List<Object?> get props => [connectedDevice, archives];
}

class DownloadingState extends DeviceFlowState {
  final Device connectedDevice;
  final ArchiveEntry entry;

  /// Progress from 0.0 .. 1.0
  final double progress;

  final String speedLabel;

  final int? fileSize;

  final double? elapsedTime;

  const DownloadingState({
    required this.connectedDevice,
    required this.entry,
    required this.progress,
    required this.speedLabel,
    this.fileSize,
    this.elapsedTime,
  });

  @override
  List<Object?> get props =>
      [connectedDevice, entry, progress, speedLabel, fileSize, elapsedTime];
}

// 6) Table view with downloaded data (web-service like table).
class TableViewState extends DeviceFlowState {
  final Device connectedDevice;
  final ArchiveEntry entry;
  final List<TableRowData> rows;
  final List<Operation> operations;
  final bool isLoading;
  const TableViewState({
    required this.connectedDevice,
    required this.entry,
    required this.rows,
    this.operations = const [],
    this.isLoading = false,
  });

  @override
  List<Object?> get props =>
      [connectedDevice, entry, rows, operations, isLoading];
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

// Экспорт в процессе
class ExportingState extends DeviceFlowState {
  final double progress; // 0..1
  final ArchiveEntry entry;
  final Device connectedDevice;
  const ExportingState(this.progress,
      {required this.entry, required this.connectedDevice});

  @override
  List<Object?> get props => [progress, entry, connectedDevice];
}

// Экспорт завершился успешно
class ExportSuccessState extends DeviceFlowState {
  const ExportSuccessState();
}

// Нет интернета – архив сохранён локально
class NetErrorState extends DeviceFlowState {
  final String dbPath;
  const NetErrorState(this.dbPath);

  @override
  List<Object?> get props => [dbPath];
}
