import 'package:bluetooth_per/common/bloc/operation_sending_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/sending_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class SendingProgressWidget extends StatelessWidget {
  const SendingProgressWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OperationSendingCubit, SendingState>(
        builder: (context, state) {
      if (state is ErrorSendingState) {
        return Text(
            Intl.message('Ошибка отправки. Код: ', name: 'sendError') +
                state.errorCode.toString(),
            style: const TextStyle(color: Colors.red));
      }
      if (state is ProcessingSendingState) {
        return LinearProgressIndicator(value: state.percent, minHeight: 8);
      }
      return const SizedBox.shrink();
    });
  }
}
