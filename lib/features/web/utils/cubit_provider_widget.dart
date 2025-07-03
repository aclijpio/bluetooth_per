import 'package:bluetooth_per/core/data/main_data.dart';
import 'package:bluetooth_per/features/web/presentation/bloc/operations_cubit.dart';
import 'package:bluetooth_per/common/bloc/operation_sending_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CubitProviderWidget extends StatelessWidget {
  const CubitProviderWidget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<OperationsCubit>(
            create: (context) => OperationsCubit(context.read<MainData>())),
        BlocProvider<OperationSendingCubit>(
            create: (context) =>
                OperationSendingCubit(context.read<MainData>())),
      ],
      child: child,
    );
  }
}
