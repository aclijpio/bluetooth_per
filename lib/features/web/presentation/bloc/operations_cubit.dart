import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/main_data.dart';
import '../../../../core/data/source/operation.dart';
import 'operations_state.dart';

class OperationsCubit extends Cubit<OperationsState> {
  final MainData _mainData;
  bool _cancelRequested = false;

  OperationsCubit(this._mainData) : super(EmptyOperationsState());

  getOperations() async {
    emit(LoadingOperationsState());
    _cancelRequested = false;
    OperStatus status = await _mainData.awaitOperations();

    if (status == OperStatus.ok) {
      for (Operation op in _mainData.operations) {
        if (_cancelRequested) {
          emit(EmptyOperationsState());
          return;
        }
        status = await _mainData.awaitOperationPoints(op);
        if (status != OperStatus.ok) break;
      }
    }

    if (status == OperStatus.ok) {
      if (_cancelRequested) {
        emit(EmptyOperationsState());
        return;
      }
      status = await _mainData.awaitOperationsCanSendStatus();
    }

    if (status == OperStatus.ok) {
      emit(LoadedOperationsState());
    } else {
      emit(ErrorOperationsState(status.index));
    }
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
    emit(EmptyOperationsState());
  }
}
