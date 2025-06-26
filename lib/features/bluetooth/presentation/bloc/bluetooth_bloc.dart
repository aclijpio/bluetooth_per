import 'package:bluetooth_per/features/web/data/repositories/main_data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bluetooth_device.dart';
import '../../domain/entities/file_download_info.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../../../../core/utils/db_update_checker.dart';
import 'bluetooth_event.dart';
import 'bluetooth_state.dart';

class BluetoothBloc extends Bloc<BluetoothEvent, BluetoothState> {
  final BluetoothRepository repository;
  final MainData mainData;
  static const platform = MethodChannel('bluetooth_per/files');

  void _log(String message) {
    // ignore: avoid_print
    print('[BluetoothBloc] $message');
  }

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
    on<RequestArchiveUpdate>(_onRequestArchiveUpdate);
    on<ArchiveUpdating>(_onArchiveUpdating);
    on<ArchiveReady>(_onArchiveReady);
    on<RunFullWorkflow>(_onRunFullWorkflow);
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
    const maxAttempts = 3;
    int attempt = 0;
    List<BluetoothDeviceEntity> foundDevices = [];

    while (attempt < maxAttempts && foundDevices.isEmpty) {
      emit(BluetoothLoading());
      final result = await repository.scanForDevices();

      bool shouldBreak = false;

      result.fold(
        (failure) {
          emit(BluetoothError(failure.message));
          shouldBreak = true;
        },
        (devices) {
          foundDevices = devices;
          emit(BluetoothScanning(devices));

          final quantorDevices = devices
              .where((d) => (d.name ?? '').toLowerCase().contains('quantor'))
              .toList();

          if (quantorDevices.length == 1) {
            add(ConnectToDevice(quantorDevices.first));
            shouldBreak = true;
          } else if (quantorDevices.isNotEmpty) {
            shouldBreak = true;
          }
        },
      );

      if (shouldBreak) break;

      attempt++;
      if (attempt < maxAttempts && foundDevices.isEmpty) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    if (foundDevices.isEmpty) {
      emit(const BluetoothError('Устройства не найдены, повторите поиск'));
    }
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
          (success) {
            emit(BluetoothConnected(
              device: event.device,
              fileList: [],
            ));
            // После подключения инициируем запрос обновления архива
            add(const RequestArchiveUpdate());
          },
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
    final updatedDownloadInfo =
        Map<String, FileDownloadInfo>.from(downloadInfo);

    emit(BluetoothConnected(
      device: connectedState.device,
      fileList: connectedState.fileList,
      downloadInfo: updatedDownloadInfo,
    ));

    final result = await repository.downloadFile(
      event.fileName,
      connectedState.device,
      onProgress: (progress, fileSize) {
        add(UpdateDownloadProgress(
          fileName: event.fileName,
          progress: progress,
          fileSize: fileSize,
        ));
      },
      onComplete: (filePath) async {
        add(CompleteDownload(
          fileName: event.fileName,
          filePath: filePath,
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
        add(UpdateDownloadProgress(
          fileName: event.fileName,
          progress: downloadInfo[event.fileName]?.progress ?? 0,
          fileSize: downloadInfo[event.fileName]?.fileSize,
        ));

        downloadInfo[event.fileName] = downloadInfo[event.fileName]!.copyWith(
          error: failure.message,
          isDownloading: false,
        );

        emit(BluetoothConnected(
          device: connectedState.device,
          fileList: connectedState.fileList,
          downloadInfo: Map<String, FileDownloadInfo>.from(downloadInfo),
        ));
      },
      (success) {
        downloadInfo[event.fileName] = downloadInfo[event.fileName]!.copyWith(
          isDownloading: false,
          isCompleted: true,
          endTime: DateTime.now(),
        );
        emit(BluetoothConnected(
          device: connectedState.device,
          fileList: connectedState.fileList,
          downloadInfo: Map<String, FileDownloadInfo>.from(downloadInfo),
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

      final percent = (event.progress * 100).toStringAsFixed(1);
      final total = event.fileSize != null ? ' / ${event.fileSize} bytes' : '';
      _log('Downloading ${event.fileName}: $percent%$total');

      emit(FileDownloading(fileName: event.fileName, progress: event.progress));

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

      if (event.fileName.toLowerCase().endsWith('.db') ||
          event.fileName.toLowerCase().endsWith('.db.gz')) {
        mainData.dbPath = event.filePath;
        mainData.resetOperationData();
        emit(BluetoothNavigateToWebExport());
      }
    }
  }

  Future<void> _onRequestArchiveUpdate(
    RequestArchiveUpdate event,
    Emitter<BluetoothState> emit,
  ) async {
    if (state is BluetoothConnected) {
      final s = state as BluetoothConnected;
      emit(ArchiveUpdatingState(
        device: s.device,
        fileList: s.fileList,
        downloadInfo: s.downloadInfo,
      ));
    }
    await for (final status in repository.requestArchiveUpdate()) {
      if (status == 'ARCHIVE_UPDATING') {
        add(const ArchiveUpdating());
      } else if (status == 'ARCHIVE_READY') {
        add(const ArchiveReady());
        break;
      }
    }
  }

  void _onArchiveUpdating(
    ArchiveUpdating event,
    Emitter<BluetoothState> emit,
  ) {
    if (state is BluetoothConnected) {
      final s = state as BluetoothConnected;
      emit(ArchiveUpdatingState(
        device: s.device,
        fileList: s.fileList,
        downloadInfo: s.downloadInfo,
      ));
    }
  }

  void _onArchiveReady(
    ArchiveReady event,
    Emitter<BluetoothState> emit,
  ) {
    if (state is BluetoothConnected) {
      final s = state as BluetoothConnected;
      emit(ArchiveReadyState(
        device: s.device,
        fileList: s.fileList,
        downloadInfo: s.downloadInfo,
      ));

      const fileName = 'database.db';
      _log('Auto-start download after archive ready');
      add(DownloadFile(fileName));
    }
  }

  Future<void> _onRunFullWorkflow(
    RunFullWorkflow event,
    Emitter<BluetoothState> emit,
  ) async {
    _log('=== FULL WORKFLOW STARTED ===');
    try {
      emit(BluetoothLoading());

      // 1. Ensure Bluetooth enabled
      _log('Step 1: checking Bluetooth enabled');
      var isEnabledResult = await repository.isBluetoothEnabled();
      bool isEnabled = false;
      isEnabledResult.fold((failure) {}, (value) => isEnabled = value);

      if (!isEnabled) {
        _log('Bluetooth is off, enabling...');
        final enableResult = await repository.enableBluetooth();
        enableResult.fold(
          (failure) => emit(BluetoothError(failure.message)),
          (_) {},
        );
      }

      // 2. Scan devices
      _log('Step 2: scanning devices');
      final scanResult = await repository.scanForDevices();
      late BluetoothDeviceEntity targetDevice;
      bool found = false;
      scanResult.fold(
        (failure) => emit(BluetoothError(failure.message)),
        (devices) {
          targetDevice = devices.firstWhere(
              (d) => d.name?.toLowerCase().contains('quantor') == true);
          found = true;
          emit(BluetoothScanning([targetDevice]));
        },
      );

      if (!found) {
        emit(const BluetoothError('Устройство Quantor не найдено'));
        return;
      }

      // 3. Connect
      _log('Step 3: connecting to device ${targetDevice.address}');
      final connectRes = await repository.connectToDevice(targetDevice);
      bool connected = false;
      connectRes.fold(
        (failure) => emit(BluetoothError(failure.message)),
        (success) {
          connected = true;
          emit(BluetoothConnected(
            device: targetDevice,
            fileList: [],
          ));
          _log('Connected to device');
        },
      );

      if (!connected) {
        return;
      }

      // 4. Request archive update and wait ready
      _log('Step 4: requesting archive update');
      bool stale = await DbUpdateChecker.isStale();
      if (stale) {
        _log('Step 4: archive is stale, requesting update');
        emit(ArchiveUpdatingState(
            device: targetDevice, fileList: const [], downloadInfo: const {}));
        await for (final status in repository.requestArchiveUpdate()) {
          if (status == 'ARCHIVE_READY') {
            _log('Archive is ready');
            break;
          }
        }

        emit(ArchiveReadyState(
            device: targetDevice, fileList: const [], downloadInfo: const {}));
      } else {
        _log(
            'Archive is fresh (< ${DbUpdateChecker.maxAge.inHours}h), skip update');
      }

      // 5. Download file
      _log('Step 5: starting file download');
      const fileName = 'database.db';
      final result = await repository.downloadFile(
        fileName,
        targetDevice,
        onProgress: (progress, fileSize) {
          add(UpdateDownloadProgress(
            fileName: fileName,
            progress: progress,
            fileSize: fileSize,
          ));
        },
        onComplete: (filePath) async {
          add(CompleteDownload(
            fileName: fileName,
            filePath: filePath,
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
          _log('Download failed: ${failure.message}');
          emit(BluetoothError(failure.message));
        },
        (_) {
          _log('Download completed');
          DbUpdateChecker.markNow();
        },
      );

      _log('=== FULL WORKFLOW FINISHED ===');
    } catch (e) {
      emit(BluetoothError(e.toString()));
    }
  }
}
