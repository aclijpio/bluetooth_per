import 'package:bluetooth_per/features/web/data/repositories/main_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';

class RepositoryProviderWidget extends StatelessWidget {
  const RepositoryProviderWidget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MainData>(create: (context) => sl<MainData>()),
      ],
      child: child,
    );
  }
}
