import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/main_data.dart';
import '../../../../core/data/source/operation.dart';
import '../../../../core/utils/background_operations_manager.dart';
import '../../../../core/utils/log_manager.dart';
import 'operations_state.dart';

class OperationsCubit extends Cubit<OperationsState> {
  final MainData _mainData;
  bool _cancelRequested = false;

  OperationsCubit(this._mainData) : super(EmptyOperationsState());

  getOperations() async {
    await BackgroundOperationsManager.ensureWakeLockForOperation();
    emit(LoadingOperationsState());
    _cancelRequested = false;
    OperStatus status = await _mainData.awaitOperations();

    if (status == OperStatus.ok) {
      for (Operation op in _mainData.operations) {
        if (_cancelRequested) {
          BackgroundOperationsManager.releaseWakeLockAfterOperation();
          emit(EmptyOperationsState());
          return;
        }
        status = await _mainData.awaitOperationPoints(op);
        if (status != OperStatus.ok) break;
      }
    }

    if (status == OperStatus.ok) {
      if (_cancelRequested) {
        BackgroundOperationsManager.releaseWakeLockAfterOperation();
        emit(EmptyOperationsState());
        return;
      }
      status = await _mainData.awaitOperationsCanSendStatus();
    }

    if (status == OperStatus.ok) {
      LogManager.info('APP',
          'Операции успешно загружены: ${_mainData.operations.length} операций');
      emit(LoadedOperationsState());
    } else {
      String errorMsg = '';
      switch (status) {
        case OperStatus.dbError:
          errorMsg = 'Ошибка базы данных при загрузке операций';
          break;
        case OperStatus.netError:
          errorMsg = 'Ошибка сети при проверке статуса операций';
          break;
        case OperStatus.filePathError:
          errorMsg = 'Ошибка пути к файлу БД';
          break;
        default:
          errorMsg = 'Неизвестная ошибка при загрузке операций';
      }
      LogManager.error('APP', errorMsg);
      emit(ErrorOperationsState(status.index));
    }

    BackgroundOperationsManager.releaseWakeLockAfterOperation();
  }

  clearOperations() {
    _mainData.resetOperationData();
    emit(EmptyOperationsState());
  }

  globalChangeSelected() {
    _mainData.globalChangeSelected();
    emit(LoadedOperationsState());
  }

  webTest() {
    _mainData.webCmdTest();
  }

  loadingTest() {
    emit(LoadingOperationsState());
  }

  void cancelGetOperations() {
    _cancelRequested = true;
    BackgroundOperationsManager.releaseWakeLockAfterOperation();
    emit(EmptyOperationsState());
  }
}
