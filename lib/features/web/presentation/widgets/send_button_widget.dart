import 'package:bluetooth_per/common/bloc/operation_sending_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/sending_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class SendButtonWidget extends StatelessWidget {
  const SendButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OperationSendingCubit, SendingState>(
      builder: (context, state) {
        return ElevatedButton(
          onPressed: () {
            if (state is ProcessingSendingState) {
              context.read<OperationSendingCubit>().needBrakeFlag = true;
            } else {
              context.read<OperationSendingCubit>().sendOperationList(() {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  duration: Duration(seconds: 1),
                  content: Text(Intl.message('Экспорт данных завершен',
                      name: 'exportComplete')),
                ));
              });
            }
          },
          child: Text(
              state is ProcessingSendingState ? 'Остановить' : 'Отправить'),
        );
      },
    );
  }
}
