import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../../bluetooth/presentation/widgets/device_list.dart';
import '../../../bluetooth/presentation/widgets/status_bar.dart';
import '../../../web/data/repositories/main_data.dart';
import '../../../web/presentation/widgets/device_info_widget.dart';
import '../../../web/presentation/widgets/file_path_widget.dart';
import '../../../web/presentation/widgets/operations_list_widget.dart';
import '../../../web/presentation/widgets/sending_progress_widget.dart';
import '../widgets/unified_action_button.dart';

class UnifiedPage extends StatelessWidget {
  const UnifiedPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<BluetoothBloc, BluetoothState>(
          builder: (context, state) {
            final mainData = context.read<MainData>();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StatusBar(),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: UnifiedActionButton(),
                ),
                const DeviceList(),
                if (mainData.dbPath.isNotEmpty)
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          FilePathWidget(),
                          SizedBox(height: 12),
                          DeviceInfoWidget(),
                          SizedBox(height: 8),
                          Expanded(child: OperationsListWidget()),
                          SizedBox(height: 8),
                          SendingProgressWidget(),
                        ],
                      ),
                    ),
                  ),
                if (mainData.dbPath.isEmpty &&
                    state is BluetoothConnected &&
                    state.fileList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Список файлов пуст. Нажмите кнопку "Get File List" в блоке устройств, чтобы повторить запрос.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
