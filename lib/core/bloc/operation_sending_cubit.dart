import 'package:bluetooth_per/core/data/main_data.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/sending_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Универсальный Cubit для отправки операций (экспорт данных)
class OperationSendingCubit extends Cubit<SendingState> {
  final MainData _mainData;
  OperationSendingCubit(this._mainData) : super(StopSendingState(0));

  bool needBrakeFlag = false;

  Future<void> sendOperationList(Function doneFunc) async {
    emit(ProcessingSendingState(0));
    List<Operation> sendList =
        _mainData.operations.where((e) => e.canSend && e.selected).toList();
    if (sendList.isEmpty) {
      emit(StopSendingState(0));
      return;
    }

    for (int i = 0; i < sendList.length; i++) {
      if (needBrakeFlag) {
        _mainData.allSelectedFlagSynchronize();
        emit(StopSendingState(0));
        needBrakeFlag = false;
        break;
      }

      int resCode = await _mainData.awaitSendingOperation(sendList[i]);
      if (resCode == 200) {
        sendList[i].selected = false;
        sendList[i].canSend = false;
        emit(ProcessingSendingState((i + 1) / sendList.length));
      } else {
        emit(ErrorSendingState(0, resCode));
        return;
      }
    }

    _mainData.allSelectedFlagSynchronize();
    emit(StopSendingState(1));
    doneFunc();
  }

  Future<void> sendOperationListWithProgress(
      Function doneFunc, void Function(Operation, double) onProgress) async {
    emit(ProcessingSendingState(0));
    List<Operation> sendList =
        _mainData.operations.where((e) => e.canSend && e.selected).toList();
    if (sendList.isEmpty) {
      emit(StopSendingState(0));
      return;
    }

    for (int i = 0; i < sendList.length; i++) {
      if (needBrakeFlag) {
        _mainData.allSelectedFlagSynchronize();
        emit(StopSendingState(0));
        needBrakeFlag = false;
        break;
      }

      int resCode = await _mainData
          .awaitSendingOperationWithProgress(sendList[i], (progress) {
        onProgress(sendList[i], progress);
      });
      if (resCode == 200) {
        sendList[i].selected = false;
        sendList[i].canSend = false;
        emit(ProcessingSendingState((i + 1) / sendList.length));
      } else {
        emit(ErrorSendingState(0, resCode));
        return;
      }
    }

    _mainData.allSelectedFlagSynchronize();
    emit(StopSendingState(1));
    doneFunc();
  }

  void resetSendingState() {
    emit(StopSendingState(0));
  }
}
