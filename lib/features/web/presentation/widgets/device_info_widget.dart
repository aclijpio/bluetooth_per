import 'package:bluetooth_per/core/data/main_data.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/operations_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/operations_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeviceInfoWidget extends StatelessWidget {
  const DeviceInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OperationsCubit, OperationsState>(
      builder: (context, state) {
        if (state is EmptyOperationsState) {
          return Text('Выберите файл для загрузки');
        } /*else if (state is ErrorOperationsState) {
          //ok, dbError, netError, filePathError
          return Text(
            state.errorCode == 1
                ? 'Ошибка чтения файла базы данных'
                : state.errorCode == 2
                    ? 'Ошибка получения данных с сервера'
                    : state.errorCode == 3
                        ? 'Файл не выбран'
                        : 'При загрузке файла произошла ошибка. Код ошибки: ${state.errorCode}',
            style: const TextStyle(color: Colors.red),
          );
        } */
        else {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  'Серийный номер прибора: ${context.read<MainData>().deviceInfo.serialNum}'),
              SizedBox(width: 20),
              Text(
                  'Гос номер агрегата: ${context.read<MainData>().deviceInfo.gosNum}'),
            ],
          );
        }
      },
    );
  }
}
