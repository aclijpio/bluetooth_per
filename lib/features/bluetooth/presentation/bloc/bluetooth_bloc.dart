import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/bluetooth_device.dart';
import '../../domain/entities/file_download_info.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import 'bluetooth_event.dart';
import 'bluetooth_state.dart';
import 'package:flutter/services.dart';
import 'package:bluetooth_per/features/web/data/repositories/main_data.dart';

class BluetoothBloc extends Bloc<BluetoothEvent, BluetoothState> {
  final BluetoothRepository repository;
  final MainData mainData;
  static const platform = MethodChannel('bluetooth_per/files');

  BluetoothBloc({
    required this.repository,
    required this.mainData,
  }) : super(BluetoothInitial()) {
    on<CheckBluetoothStatus>(_onCheckBluetoothStatus);
    on<EnableBluetooth>(_onEnableBluetooth);
    on<StartScanning>(_onStartScanning);
    on<StopScanning>(_onStopScanning);
    on<ConnectToDevice>(_onConnectToDevice);
    on<DisconnectFromDevice>(_onDisconnectFromDevice);
    on<GetFileList>(_onGetFileList);
    on<DownloadFile>(_onDownloadFile);
    on<CancelDownload>(_onCancelDownload);
    on<UpdateDownloadProgress>(_onUpdateDownloadProgress);
    on<CompleteDownload>(_onCompleteDownload);
  }

  Future<void> _onCheckBluetoothStatus(
    CheckBluetoothStatus event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(BluetoothLoading());
    final result = await repository.isBluetoothEnabled();
    result.fold(
      (failure) => emit(BluetoothError(failure.message)),
      (isEnabled) => emit(isEnabled ? BluetoothEnabled() : BluetoothDisabled()),
    );
  }

  Future<void> _onEnableBluetooth(
    EnableBluetooth event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(BluetoothLoading());
    final result = await repository.enableBluetooth();
    result.fold(
      (failure) => emit(BluetoothError(failure.message)),
      (success) => emit(BluetoothEnabled()),
    );
  }

  Future<void> _onStartScanning(
    StartScanning event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(BluetoothLoading());
    final result = await repository.scanForDevices();
    result.fold(
      (failure) => emit(BluetoothError(failure.message)),
      (devices) {
        emit(BluetoothScanning(devices));
        // Автоподключение к Quantor
        BluetoothDeviceEntity? quantor;
        try {
          quantor = devices.firstWhere(
            (d) => (d.name ?? '').toLowerCase().contains('quantor'),
          );
        } catch (_) {
          quantor = null;
        }
        if (quantor != null) {
          add(ConnectToDevice(quantor));
        }
      },
    );
  }

  Future<void> _onStopScanning(
    StopScanning event,
    Emitter<BluetoothState> emit,
  ) async {
    // Стоп сканинг
  }

  Future<void> _onConnectToDevice(
    ConnectToDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    try {
      emit(BluetoothLoading());
      final result = await repository.connectToDevice(event.device);

      if (!emit.isDone) {
        result.fold(
          (failure) => emit(BluetoothError(failure.message)),
          (success) => emit(BluetoothConnected(
            device: event.device,
            fileList: [],
          )),
        );
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(BluetoothError(e.toString()));
      }
    }
  }

  Future<void> _onDisconnectFromDevice(
    DisconnectFromDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(BluetoothLoading());
    final result = await repository.disconnectFromDevice(event.device);
    result.fold(
      (failure) => emit(BluetoothError(failure.message)),
      (success) async {
        final scanResult = await repository.scanForDevices();
        scanResult.fold(
          (failure) => emit(BluetoothError(failure.message)),
          (devices) => emit(BluetoothScanning(devices)),
        );
      },
    );
  }

  Future<void> _onGetFileList(
    GetFileList event,
    Emitter<BluetoothState> emit,
  ) async {
    if (state is! BluetoothConnected) {
      emit(const BluetoothError('Not connected to any device'));
      return;
    }

    final connectedState = state as BluetoothConnected;
    try {
      emit(BluetoothConnected(
        device: connectedState.device,
        fileList: connectedState.fileList,
        downloadInfo: connectedState.downloadInfo,
      ));

      final result = await repository.getFileList();

      if (!emit.isDone) {
        result.fold(
          (failure) => emit(BluetoothError(failure.message)),
          (fileList) => emit(BluetoothConnected(
            device: connectedState.device,
            fileList: fileList,
            downloadInfo: connectedState.downloadInfo,
          )),
        );
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(BluetoothError(e.toString()));
      }
    }
  }

  Future<void> _onDownloadFile(
    DownloadFile event,
    Emitter<BluetoothState> emit,
  ) async {
    if (state is! BluetoothConnected) {
      emit(const BluetoothError('Not connected to any device'));
      return;
    }

    final connectedState = state as BluetoothConnected;
    final downloadInfo =
        Map<String, FileDownloadInfo>.from(connectedState.downloadInfo);

    downloadInfo[event.fileName] = FileDownloadInfo(
      fileName: event.fileName,
      startTime: DateTime.now(),
      isDownloading: true,
    );

    print('Starting download for ${event.fileName}');
    final updatedDownloadInfo = Map<String, FileDownloadInfo>.from(downloadInfo);

    emit(BluetoothConnected(
      device: connectedState.device,
      fileList: connectedState.fileList,
      downloadInfo: updatedDownloadInfo,
    ));

    final result = await repository.downloadFile(
      event.fileName,
      connectedState.device,
      onProgress: (progress, fileSize) {
        print('Progress callback received: $progress, size: $fileSize');
        final bytesReceived =
            fileSize != null ? (progress * fileSize).round() : 0;
        downloadInfo[event.fileName] = downloadInfo[event.fileName]!.copyWith(
          progress: progress,
          fileSize: fileSize,
          bytesReceived: bytesReceived,
          lastUpdateTime: DateTime.now(),
        );
        final updatedDownloadInfo =
            Map<String, FileDownloadInfo>.from(downloadInfo);

        emit(BluetoothConnected(
          device: connectedState.device,
          fileList: connectedState.fileList,
          downloadInfo: updatedDownloadInfo,
        ));
      },
      onComplete: (filePath) async {
        print('Download completed for ${event.fileName}');
        downloadInfo[event.fileName] = downloadInfo[event.fileName]!.copyWith(
          isDownloading: false,
          isCompleted: true,
          endTime: DateTime.now(),
          filePath: filePath,
        );

        if (event.fileName.toLowerCase().endsWith('.db')) {
          print('Setting database path in MainData: $filePath');
          mainData.dbPath = filePath;
        }

        final updatedDownloadInfo =
            Map<String, FileDownloadInfo>.from(downloadInfo);

        emit(BluetoothConnected(
          device: connectedState.device,
          fileList: connectedState.fileList,
          downloadInfo: updatedDownloadInfo,
        ));

        try {
          await platform.invokeMethod('openFolder', {'filePath': filePath});
        } catch (e) {
          print('Ошибка открытия папки: $e');
        }
      },
    );

    result.fold(
      (failure) {
        print('Download failed for ${event.fileName}: ${failure.message}');
        downloadInfo[event.fileName] = downloadInfo[event.fileName]!.copyWith(
          error: failure.message,
          isDownloading: false,
        );
        final updatedDownloadInfo =
            Map<String, FileDownloadInfo>.from(downloadInfo);

        emit(BluetoothConnected(
          device: connectedState.device,
          fileList: connectedState.fileList,
          downloadInfo: updatedDownloadInfo,
        ));
      },
      (success) {
        print('Download succeeded for ${event.fileName}');
        downloadInfo[event.fileName] = downloadInfo[event.fileName]!.copyWith(
          isDownloading: false,
          isCompleted: true,
          endTime: DateTime.now(),
        );
        final updatedDownloadInfo =
            Map<String, FileDownloadInfo>.from(downloadInfo);

        emit(BluetoothConnected(
          device: connectedState.device,
          fileList: connectedState.fileList,
          downloadInfo: updatedDownloadInfo,
        ));
      },
    );
  }

  Future<void> _onCancelDownload(
    CancelDownload event,
    Emitter<BluetoothState> emit,
  ) async {
    if (state is! BluetoothConnected) {
      return;
    }

    final connectedState = state as BluetoothConnected;
    final downloadInfo =
        Map<String, FileDownloadInfo>.from(connectedState.downloadInfo);

    if (downloadInfo.containsKey(event.fileName)) {
      final result = await repository.cancelDownload();

      result.fold(
        (failure) {
          downloadInfo[event.fileName] = downloadInfo[event.fileName]!.copyWith(
            error: failure.message,
            isDownloading: false,
          );
        },
        (_) {
          downloadInfo[event.fileName] = downloadInfo[event.fileName]!.copyWith(
            isDownloading: false,
            error: 'Download cancelled',
          );
        },
      );

      final updatedDownloadInfo =
          Map<String, FileDownloadInfo>.from(downloadInfo);

      emit(BluetoothConnected(
        device: connectedState.device,
        fileList: connectedState.fileList,
        downloadInfo: updatedDownloadInfo,
      ));
    }
  }

  void _onUpdateDownloadProgress(
    UpdateDownloadProgress event,
    Emitter<BluetoothState> emit,
  ) {
    if (state is! BluetoothConnected) return;

    final connectedState = state as BluetoothConnected;
    final downloadInfo =
        Map<String, FileDownloadInfo>.from(connectedState.downloadInfo);

    if (downloadInfo.containsKey(event.fileName)) {
      downloadInfo[event.fileName] = downloadInfo[event.fileName]!.copyWith(
        progress: event.progress,
        fileSize: event.fileSize,
      );

      final updatedDownloadInfo =
          Map<String, FileDownloadInfo>.from(downloadInfo);

      emit(BluetoothConnected(
        device: connectedState.device,
        fileList: connectedState.fileList,
        downloadInfo: updatedDownloadInfo,
      ));
    }
  }

  void _onCompleteDownload(
    CompleteDownload event,
    Emitter<BluetoothState> emit,
  ) {
    if (state is! BluetoothConnected) return;

    final connectedState = state as BluetoothConnected;
    final downloadInfo =
        Map<String, FileDownloadInfo>.from(connectedState.downloadInfo);

    if (downloadInfo.containsKey(event.fileName)) {
      downloadInfo[event.fileName] = downloadInfo[event.fileName]!.copyWith(
        isDownloading: false,
        isCompleted: true,
        endTime: DateTime.now(),
        filePath: event.filePath,
      );

      final updatedDownloadInfo =
          Map<String, FileDownloadInfo>.from(downloadInfo);

      emit(BluetoothConnected(
        device: connectedState.device,
        fileList: connectedState.fileList,
        downloadInfo: updatedDownloadInfo,
      ));

      if (event.fileName.toLowerCase().endsWith('.db')) {
        mainData.dbPath = event.filePath;
        mainData.resetOperationData();
        emit(BluetoothNavigateToWebExport());
      }
    }
  }
}
