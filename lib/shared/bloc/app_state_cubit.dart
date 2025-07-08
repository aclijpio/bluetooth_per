import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/app_models.dart';

enum AppState {
  initial,
  searching,
  deviceFound,
  connecting,
  connected,
  downloading,
  processing,
  completed,
  error,
}

class AppStateModel extends Equatable {
  final AppState state;
  final List<DeviceModel> devices;
  final DeviceModel? connectedDevice;
  final List<ArchiveModel> archives;
  final String? errorMessage;
  final double progress;
  final bool isLoading;

  const AppStateModel({
    this.state = AppState.initial,
    this.devices = const [],
    this.connectedDevice,
    this.archives = const [],
    this.errorMessage,
    this.progress = 0.0,
    this.isLoading = false,
  });

  AppStateModel copyWith({
    AppState? state,
    List<DeviceModel>? devices,
    DeviceModel? connectedDevice,
    List<ArchiveModel>? archives,
    String? errorMessage,
    double? progress,
    bool? isLoading,
  }) {
    return AppStateModel(
      state: state ?? this.state,
      devices: devices ?? this.devices,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      archives: archives ?? this.archives,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        state,
        devices,
        connectedDevice,
        archives,
        errorMessage,
        progress,
        isLoading,
      ];
}

class AppStateCubit extends Cubit<AppStateModel> {
  AppStateCubit() : super(const AppStateModel());

  void reset() {
    emit(const AppStateModel());
  }

  void startSearching() {
    emit(state.copyWith(
      state: AppState.searching,
      isLoading: true,
      devices: [],
    ));
  }

  void addDevice(DeviceModel device) {
    final updatedDevices = List<DeviceModel>.from(state.devices);
    if (!updatedDevices.any((d) => d.macAddress == device.macAddress)) {
      updatedDevices.add(device);
      emit(state.copyWith(
        state: AppState.deviceFound,
        devices: updatedDevices,
      ));
    }
  }

  void connectToDevice(DeviceModel device) {
    emit(state.copyWith(
      state: AppState.connecting,
      connectedDevice: device,
      isLoading: true,
    ));
  }

  void deviceConnected(List<ArchiveModel> archives) {
    emit(state.copyWith(
      state: AppState.connected,
      archives: archives,
      isLoading: false,
    ));
  }

  void startDownload() {
    emit(state.copyWith(
      state: AppState.downloading,
      progress: 0.0,
      isLoading: true,
    ));
  }

  void updateProgress(double progress) {
    emit(state.copyWith(progress: progress));
  }

  void downloadCompleted() {
    emit(state.copyWith(
      state: AppState.processing,
      progress: 1.0,
      isLoading: true,
    ));
  }

  void processingCompleted() {
    emit(state.copyWith(
      state: AppState.completed,
      isLoading: false,
    ));
  }

  void showError(String message) {
    emit(state.copyWith(
      state: AppState.error,
      errorMessage: message,
      isLoading: false,
    ));
  }
}
