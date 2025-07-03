import 'package:bluetooth_per/core/data/main_data.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/operations_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/operations_state.dart';
import 'package:bluetooth_per/common/bloc/operation_sending_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/sending_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class OperationsListWidget extends StatefulWidget {
  const OperationsListWidget({super.key});

  @override
  State<OperationsListWidget> createState() => _OperationsListWidgetState();
}

class _OperationsListWidgetState extends State<OperationsListWidget> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OperationSendingCubit, SendingState>(
        builder: (context, sendState) {
      return Column(
        children: [
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            value: context.read<MainData>().allSelected,
            onChanged: (value) {
              context.read<MainData>().allSelected = value!;
              context.read<OperationsCubit>().globalChangeSelected();
              context.read<MainData>().allSelectedFlagSynchronize();
              context.read<OperationsCubit>().emit(LoadedOperationsState());
              setState(() {});
            },
            title: const Row(
              children: [
                Expanded(child: Text('Дата')),
                Expanded(child: Text('Скважина')),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: BlocBuilder<OperationsCubit, OperationsState>(
              builder: (context, state) {
                if (state is LoadingOperationsState) {
                  return const Center(
                    child: SizedBox(
                      height: 100,
                      width: 100,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (context.read<MainData>().operations.isEmpty) {
                  return const Center(child: Text('Нет операций'));
                }

                final allOps =
                    context.read<MainData>().operations.reversed.toList();
                print(
                    '[OperationsListWidget] Всего операций: ${allOps.length}');
                for (final op in allOps) {
                  print(
                      '[OperationsListWidget] dt=${op.dt} canSend=${op.canSend} selected=${op.selected}');
                }

                List<Operation> operations =
                    allOps.where((op) => op.canSend).toList();
                print(
                    '[OperationsListWidget] Отображается операций: ${operations.length}');

                if (operations.isEmpty) {
                  print(
                      '[OperationsListWidget] Все операции уже синхронизированы с сервером');
                  return const Center(
                    child: Text('Все операции уже синхронизированы с сервером'),
                  );
                }

                return ListView.builder(
                  itemCount: operations.length,
                  itemBuilder: (context, index) {
                    DateTime dtStart = DateTime.fromMillisecondsSinceEpoch(
                        operations[index].dt * 1000);
                    print(
                        '[OperationsListWidget] build row dt=${operations[index].dt} canSend=${operations[index].canSend} selected=${operations[index].selected}');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(DateFormat('dd.MM.yyyy HH:mm:ss')
                                  .format(dtStart)),
                            ),
                            Expanded(child: Text(operations[index].hole)),
                            if (operations[index].checkError)
                              const Icon(Icons.error, color: Colors.red),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
