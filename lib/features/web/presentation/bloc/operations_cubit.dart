import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/main_data.dart';
import '../../data/source/operation.dart';
import 'operations_state.dart';


class OperationsCubit extends Cubit<OperationsState> {
  final MainData _mainData;
  OperationsCubit(this._mainData) : super(EmptyOperationsState());

  getOperations() async {
    emit(LoadingOperationsState());
    OperStatus status = await _mainData.awaitOperations();

    if (status == OperStatus.ok) {
      for (Operation op in _mainData.operations) {
        status = await _mainData.awaitOperationPoints(op);
        if (status != OperStatus.ok) break;
      }
    }

    if (status == OperStatus.ok) {
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

  globalChangeSelected() => _mainData.globalChangeSelected();

  webTest() {
    _mainData.webCmdTest();
  }

  loadingTest() {
    emit(LoadingOperationsState());
  }
}
