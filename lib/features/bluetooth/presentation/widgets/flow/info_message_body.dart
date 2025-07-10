import 'package:flutter/material.dart';

import '../../../../../core/widgets/primary_button.dart';
import '../../bloc/transfer_state.dart';

class InfoMessageBody extends StatelessWidget {
  final InfoMessageState state;

  const InfoMessageBody({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          state.content,
          Spacer(),
          PrimaryButton(
            label: state.buttonText,
            onPressed: state.onButtonPressed,
          ),
        ],
      ),
    );
  }
}
