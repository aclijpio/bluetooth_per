import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

enum InterfaceState {
  initial, // Начальное состояние - поиск устройств
  scanning, // Сканирование устройств
  deviceSelection, // Выбор устройства
  connected, // Подключено к устройству
  fileList, // Список файлов
  downloading, // Скачивание файла
  webExport, // Веб-экспорт данных
  archiveUpdating, // Архив обновляется
  archiveReady, // Архив готов
  error, // Ошибка
}

class UnifiedInterfaceState extends Equatable {
  final InterfaceState state;
  final String? errorMessage;
  final bool isLoading;

  const UnifiedInterfaceState({
    this.state = InterfaceState.initial,
    this.errorMessage,
    this.isLoading = false,
  });

  UnifiedInterfaceState copyWith({
    InterfaceState? state,
    String? errorMessage,
    bool? isLoading,
  }) {
    return UnifiedInterfaceState(
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [state, errorMessage, isLoading];
}

class UnifiedInterfaceCubit extends Cubit<UnifiedInterfaceState> {
  UnifiedInterfaceCubit() : super(const UnifiedInterfaceState());

  void setInitialState() {
    emit(const UnifiedInterfaceState(state: InterfaceState.initial));
  }

  void setScanningState() {
    emit(const UnifiedInterfaceState(
        state: InterfaceState.scanning, isLoading: true));
  }

  void setDeviceSelectionState() {
    emit(const UnifiedInterfaceState(state: InterfaceState.deviceSelection));
  }

  void setConnectedState() {
    emit(const UnifiedInterfaceState(state: InterfaceState.connected));
  }

  void setFileListState() {
    emit(const UnifiedInterfaceState(state: InterfaceState.fileList));
  }

  void setDownloadingState() {
    emit(const UnifiedInterfaceState(
        state: InterfaceState.downloading, isLoading: true));
  }

  void setWebExportState() {
    emit(const UnifiedInterfaceState(state: InterfaceState.webExport));
  }

  void setErrorState(String message) {
    emit(UnifiedInterfaceState(
      state: InterfaceState.error,
      errorMessage: message,
      isLoading: false,
    ));
  }

  void setLoading(bool loading) {
    emit(state.copyWith(isLoading: loading));
  }

  void setArchiveUpdatingState() {
    emit(const UnifiedInterfaceState(state: InterfaceState.archiveUpdating));
  }

  void setArchiveReadyState() {
    emit(const UnifiedInterfaceState(state: InterfaceState.archiveReady));
  }
}
