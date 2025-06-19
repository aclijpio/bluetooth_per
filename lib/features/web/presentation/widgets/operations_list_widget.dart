import 'package:bluetooth_per/features/web/data/repositories/main_data.dart';
import 'package:bluetooth_per/features/web/data/source/operation.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/operations_cubit.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/operations_state.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/sending_cubit.dart';
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
    return BlocBuilder<SendingCubit, SendingState>(
        builder: (context, sendState) {
      return Column(
        children: [
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            value: context.read<MainData>().allSelected,
            onChanged: (value) {
              context.read<MainData>().allSelected = value!;
              context.read<OperationsCubit>().globalChangeSelected();
              setState(() {});
            },
            title: const Row(
              children: [
                Expanded(child: Text('Дата')),
                Expanded(child: Text('Скважина')),
                Expanded(child: Text('Кол-во точек')),
                Expanded(child: Text('На сервере')),
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
                List<Operation> operations =
                    context.read<MainData>().operations.reversed.toList();

                return ListView.builder(
                  itemCount: operations.length,
                  itemBuilder: (context, index) {
                    DateTime dtStart = DateTime.fromMillisecondsSinceEpoch(
                        operations[index].dt * 1000);
                    return CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      value: operations[index].selected,
                      onChanged: (value) {
                        operations[index].selected = value!;
                        if (!value)
                          context.read<MainData>().allSelected = value;
                        setState(() {});
                      },
                      enabled: operations[index].canSend,
                      title: Row(
                        children: [
                          Expanded(
                              child: Text(DateFormat('dd.MM.yyyy HH:mm:ss')
                                  .format(dtStart))),
                          Expanded(child: Text(operations[index].hole)),
                          Expanded(
                              child: Text(operations[index].pCnt.toString())),
                          Expanded(
                              child: operations[index].canSend
                                  ? const Text('требуется отправка')
                                  : const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Icon(
                                        Icons.done,
                                      ),
                                    )),
                        ],
                      ),
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
