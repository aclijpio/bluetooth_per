import 'package:flutter/material.dart';

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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: state.onButtonPressed,
            child: Text(state.buttonText),
          ),
        ],
      ),
    );
  }
}
