import 'package:bluetooth_per/features/web/presentation/bloc/sending_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/main_data.dart';
import '../../data/source/operation.dart';


class SendingCubit extends Cubit<SendingState> {
  MainData _mainData;
  SendingCubit(this._mainData) : super(StopSendingState(0));

  bool needBrakeFlag = false;

  sendOperationList(Function doneFunc) async {
    emit(ProcessingSendingState(0));
    List<Operation> sendList =
        _mainData.operations.where((e) => e.canSend && e.selected).toList();
    if (sendList.isEmpty) {
      emit(StopSendingState(0));
      return;
    }

    for (int i = 0; i < sendList.length; i++) {
      //прерываем процесс отправки если флаг выставили
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

  resetSendingState() {
    emit(StopSendingState(0));
  }
}
