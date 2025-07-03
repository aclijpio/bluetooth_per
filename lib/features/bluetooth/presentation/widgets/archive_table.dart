import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/main_data.dart';
import '../models/archive_entry.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import '../bloc/device_flow_cubit.dart';
import '../bloc/device_flow_state.dart';
import 'package:bluetooth_per/common/widgets/progress_bar.dart';

class ArchiveTable extends StatelessWidget {
  final ArchiveEntry entry;
  final List<Operation> operations;
  final ValueChanged<bool>? onSelectionChanged;
  const ArchiveTable({
    super.key,
    required this.entry,
    required this.operations,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ArchiveInfo(entry: entry),
        const SizedBox(height: 20),
        _ArchiveTableHeader(
          allSelected: _allSelected(operations),
          onAllSelected: (v) {
            final updatedOps = operations
                .map((op) => op.copyWith(selected: v ?? false))
                .toList();
            onSelectionChanged?.call(updatedOps.any((op) => op.selected));
            BlocProvider.of<DeviceFlowCubit>(context)
                .updateOperations(updatedOps);
          },
        ),
        Container(height: 1, color: Colors.black.withAlpha(74)),
        const SizedBox(height: 1),
        Expanded(
          child: operations.isEmpty
              ? Center(child: Text('Нет данных'))
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: operations.length,
                  separatorBuilder: (_, __) =>
                      Container(height: 1, color: Colors.black.withAlpha(74)),
                  itemBuilder: (_, index) {
                    final op = operations[index];
                    return _ArchiveTableRow(
                      op: op,
                      onChanged: (v) {
                        final updatedOps =
                            operations.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final o = entry.value;
                          return idx == index
                              ? o.copyWith(selected: v ?? false)
                              : o;
                        }).toList();
                        onSelectionChanged
                            ?.call(updatedOps.any((e) => e.selected));
                        BlocProvider.of<DeviceFlowCubit>(context)
                            .updateOperations(updatedOps);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  bool _allSelected(List<Operation> ops) {
    if (ops.isEmpty) return false;
    return ops.every((op) => op.selected);
  }
}

class _ArchiveInfo extends StatelessWidget {
  final ArchiveEntry entry;
  const _ArchiveInfo({required this.entry});
  @override
  Widget build(BuildContext context) {
    final mainData = context.read<MainData>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F2FA),
        borderRadius: BorderRadius.circular(27),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Серийный номер: ${mainData.deviceInfo.serialNum}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 20),
          Text(
            'Гос номер: ${mainData.deviceInfo.gosNum}',
            style: const TextStyle(fontSize: 18),
          ),
          BlocBuilder<DeviceFlowCubit, DeviceFlowState>(
            builder: (context, state) {
              final operations = context.read<MainData>().operations;
              if (state is ExportingState) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: ProgressBarWithPercent(progress: state.progress),
                );
              }
              if (operations.isNotEmpty &&
                  operations.where((op) => op.canSend).isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 5.0),
                  child: Text(
                    'Нет связи с сервером или интернетом.',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

class _ArchiveTableHeader extends StatelessWidget {
  final bool allSelected;
  final ValueChanged<bool?> onAllSelected;
  const _ArchiveTableHeader(
      {required this.allSelected, required this.onAllSelected});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Row(
        children: [
          _checkbox(allSelected, onAllSelected),
          const SizedBox(width: 10),
          const Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Дата',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF222222),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Скважина',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF222222),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveTableRow extends StatelessWidget {
  final Operation op;
  final ValueChanged<bool?> onChanged;
  const _ArchiveTableRow({required this.op, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 20,
      ),
      child: Row(
        children: [
          _checkbox(
            op.selected,
            onChanged,
            enabled: op.canSend,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(
                        DateTime.fromMillisecondsSinceEpoch(op.dt * 1000)),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF484848),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    op.hole,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF484848),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: op.checkError
                      ? const Icon(Icons.error, color: Colors.red, size: 22)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _checkbox(bool value, ValueChanged<bool?>? onChanged,
    {bool enabled = true}) {
  return SizedBox(
    width: 33,
    height: 33,
    child: Checkbox(
      value: value,
      onChanged: enabled ? onChanged : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}
