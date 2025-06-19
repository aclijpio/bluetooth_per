import 'package:bluetooth_per/features/web/presentation/bloc/sending_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/sending_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendButtonWidget extends StatelessWidget {
  const SendButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SendingCubit, SendingState>(
      builder: (context, state) {
        return ElevatedButton(
          onPressed: () {
            if (state is ProcessingSendingState) {
              context.read<SendingCubit>().needBrakeFlag = true;
            } else {
              context.read<SendingCubit>().sendOperationList(() {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  duration: Duration(seconds: 1),
                  content: Text('Экспорт данных завершен'),
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
