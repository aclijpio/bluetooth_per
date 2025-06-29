import 'package:equatable/equatable.dart';
import '../models/device.dart';
import '../models/archive_entry.dart';
import '../models/table_row_data.dart';

// Base class for all states.
abstract class BluetoothFlowState extends Equatable {
  const BluetoothFlowState();

  @override
  List<Object?> get props => [];
}

// 1) Initial screen where user can start searching for devices.
class InitialSearchState extends BluetoothFlowState {
  final String? errorMessage;
  final bool canRetry;

  const InitialSearchState({
    this.errorMessage,
    this.canRetry = true,
  });

  @override
  List<Object?> get props => [errorMessage, canRetry];
}

// 2) Search in progress screen (showing spinner).
class SearchingState extends BluetoothFlowState {
  final String statusMessage;

  const SearchingState({this.statusMessage = 'Поиск устройств...'});

  @override
  List<Object?> get props => [statusMessage];
}

// 3) List of discovered devices. If the list has exactly one item, the cubit can skip this state.
class DeviceListState extends BluetoothFlowState {
  final List<Device> devices;
  final String? errorMessage;

  const DeviceListState({
    required this.devices,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [devices, errorMessage];
}

// 4) Connecting to device
class ConnectingState extends BluetoothFlowState {
  final Device device;
  final String statusMessage;

  const ConnectingState({
    required this.device,
    this.statusMessage = 'Подключение к устройству...',
  });

  @override
  List<Object?> get props => [device, statusMessage];
}

// 5) Connected to device and requesting archive update
class RequestingArchiveUpdateState extends BluetoothFlowState {
  final Device connectedDevice;
  final String statusMessage;

  const RequestingArchiveUpdateState({
    required this.connectedDevice,
    this.statusMessage = 'Запрос на обновление архива...',
  });

  @override
  List<Object?> get props => [connectedDevice, statusMessage];
}

// 6) Archive is being updated on server
class ArchiveUpdatingState extends BluetoothFlowState {
  final Device connectedDevice;
  final String statusMessage;
  final DateTime startTime;

  const ArchiveUpdatingState({
    required this.connectedDevice,
    this.statusMessage = 'Архив обновляется...',
    required this.startTime,
  });

  @override
  List<Object?> get props => [connectedDevice, statusMessage, startTime];
}

// 7) Archive is ready for download
class ArchiveReadyState extends BluetoothFlowState {
  final Device connectedDevice;
  final ArchiveEntry archive;

  const ArchiveReadyState({
    required this.connectedDevice,
    required this.archive,
  });

  @override
  List<Object?> get props => [connectedDevice, archive];
}

// 8) Download in progress for archive
class DownloadingState extends BluetoothFlowState {
  final Device connectedDevice;
  final ArchiveEntry archive;
  final double progress;
  final String speedLabel;
  final int bytesReceived;
  final int totalBytes;
  final DateTime startTime;
  final bool isPaused;
  final String? errorMessage;

  const DownloadingState({
    required this.connectedDevice,
    required this.archive,
    required this.progress,
    required this.speedLabel,
    required this.bytesReceived,
    required this.totalBytes,
    required this.startTime,
    this.isPaused = false,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [
        connectedDevice,
        archive,
        progress,
        speedLabel,
        bytesReceived,
        totalBytes,
        startTime,
        isPaused,
        errorMessage,
      ];
}

// 9) Archive downloaded and extracted
class ArchiveExtractedState extends BluetoothFlowState {
  final Device connectedDevice;
  final ArchiveEntry archive;
  final String extractedPath;

  const ArchiveExtractedState({
    required this.connectedDevice,
    required this.archive,
    required this.extractedPath,
  });

  @override
  List<Object?> get props => [connectedDevice, archive, extractedPath];
}

// 10) Loading operations from extracted archive
class LoadingOperationsState extends BluetoothFlowState {
  final Device connectedDevice;
  final ArchiveEntry archive;
  final String extractedPath;
  final int loadedOperations;
  final int totalOperations;

  const LoadingOperationsState({
    required this.connectedDevice,
    required this.archive,
    required this.extractedPath,
    this.loadedOperations = 0,
    this.totalOperations = 0,
  });

  @override
  List<Object?> get props => [
        connectedDevice,
        archive,
        extractedPath,
        loadedOperations,
        totalOperations
      ];
}

// 11) Table view with downloaded data
class TableViewState extends BluetoothFlowState {
  final Device connectedDevice;
  final ArchiveEntry archive;
  final List<TableRowData> rows;
  final bool hasSelection;

  const TableViewState({
    required this.connectedDevice,
    required this.archive,
    required this.rows,
    this.hasSelection = false,
  });

  @override
  List<Object?> get props => [connectedDevice, archive, rows, hasSelection];
}

// 12) Processing operations and finding different points
class ProcessingOperationsState extends BluetoothFlowState {
  final Device connectedDevice;
  final ArchiveEntry archive;
  final int processedOperations;
  final int totalOperations;
  final int foundDifferentPoints;

  const ProcessingOperationsState({
    required this.connectedDevice,
    required this.archive,
    this.processedOperations = 0,
    this.totalOperations = 0,
    this.foundDifferentPoints = 0,
  });

  @override
  List<Object?> get props => [
        connectedDevice,
        archive,
        processedOperations,
        totalOperations,
        foundDifferentPoints
      ];
}

// 13) Uploading different points to server
class UploadingPointsState extends BluetoothFlowState {
  final Device connectedDevice;
  final int uploadedPoints;
  final int totalPoints;
  final String statusMessage;

  const UploadingPointsState({
    required this.connectedDevice,
    this.uploadedPoints = 0,
    this.totalPoints = 0,
    this.statusMessage = 'Отправка точек на сервер...',
  });

  @override
  List<Object?> get props =>
      [connectedDevice, uploadedPoints, totalPoints, statusMessage];
}

// 14) Process completed successfully
class ProcessCompletedState extends BluetoothFlowState {
  final Device connectedDevice;
  final ArchiveEntry archive;
  final int totalPoints;
  final int differentPoints;
  final String extractedPath;

  const ProcessCompletedState({
    required this.connectedDevice,
    required this.archive,
    required this.totalPoints,
    required this.differentPoints,
    required this.extractedPath,
  });

  @override
  List<Object?> get props =>
      [connectedDevice, archive, totalPoints, differentPoints, extractedPath];
}

// 15) Error state with retry option
class ErrorState extends BluetoothFlowState {
  final String errorMessage;
  final String? errorDetails;
  final bool canRetry;
  final Device? lastConnectedDevice;

  const ErrorState({
    required this.errorMessage,
    this.errorDetails,
    this.canRetry = true,
    this.lastConnectedDevice,
  });

  @override
  List<Object?> get props =>
      [errorMessage, errorDetails, canRetry, lastConnectedDevice];
}
