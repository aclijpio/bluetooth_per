import 'package:bluetooth_per/features/web/presentation/bloc/sending_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/sending_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


class SendingProgressWidget extends StatelessWidget {
  const SendingProgressWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SendingCubit, SendingState>(builder: (context, state) {
      if (state is ErrorSendingState) {
        return Text(
          'Ошибка отправки операций. Код ошибки: ${state.errorCode}',
          style: const TextStyle(color: Colors.red),
        );
      } else {
        return LinearProgressIndicator(
          value: state.percent,
          minHeight: 7,
        );
      }
    });
  }
}
