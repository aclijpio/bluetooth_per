import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import 'bluetooth_event.dart';
import 'bluetooth_state.dart';

class BluetoothBloc extends Bloc<BluetoothEvent, BluetoothState> {
  final BluetoothRepository repository;

  BluetoothBloc({required this.repository}) : super(BluetoothInitial()) {
    on<CheckBluetoothStatus>(_onCheckBluetoothStatus);
    on<EnableBluetooth>(_onEnableBluetooth);
    on<StartScanning>(_onStartScanning);
    on<StopScanning>(_onStopScanning);
    on<ConnectToDevice>(_onConnectToDevice);
    on<DisconnectFromDevice>(_onDisconnectFromDevice);
    on<GetFileList>(_onGetFileList);
    on<DownloadFile>(_onDownloadFile);
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
      (devices) => emit(BluetoothScanning(devices)),
    );
  }

  Future<void> _onStopScanning(
    StopScanning event,
    Emitter<BluetoothState> emit,
  ) async {
    // Implement stop scanning logic
  }

  Future<void> _onConnectToDevice(
    ConnectToDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(BluetoothLoading());
    final result = await repository.connectToDevice(event.device);
    result.fold(
      (failure) => emit(BluetoothError(failure.message)),
      (success) async {
        final fileListResult = await repository.getFileList();
        fileListResult.fold(
          (failure) => emit(BluetoothError(failure.message)),
          (fileList) => emit(BluetoothConnected(
            device: event.device,
            fileList: fileList,
          )),
        );
      },
    );
  }

  Future<void> _onDisconnectFromDevice(
    DisconnectFromDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(BluetoothLoading());
    final result = await repository.disconnectFromDevice(event.device);
    result.fold(
      (failure) => emit(BluetoothError(failure.message)),
      (success) => emit(BluetoothDisconnected()),
    );
  }

  Future<void> _onGetFileList(
    GetFileList event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(BluetoothLoading());
    final result = await repository.getFileList();
    result.fold(
      (failure) => emit(BluetoothError(failure.message)),
      (fileList) => emit(BluetoothConnected(
        device: (state as BluetoothConnected).device,
        fileList: fileList,
      )),
    );
  }

  Future<void> _onDownloadFile(
    DownloadFile event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(FileDownloading(fileName: event.fileName, progress: 0.0));
    final result = await repository.downloadFile(event.fileName);
    result.fold(
      (failure) => emit(BluetoothError(failure.message)),
      (success) => emit(FileDownloaded(
        fileName: event.fileName,
        filePath: '', // TODO: Реализовать обработку путей к файлам
      )),
    );
  }
} 