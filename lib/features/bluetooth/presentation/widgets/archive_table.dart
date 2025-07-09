import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bluetooth_per/common/config.dart';

import '../../../../core/data/main_data.dart';
import '../models/archive_entry.dart';
import 'package:bluetooth_per/core/data/source/operation.dart';
import '../bloc/transfer_cubit.dart';
import '../bloc/transfer_state.dart';
import 'package:bluetooth_per/common/widgets/progress_bar.dart';

class ArchiveTable extends StatelessWidget {
  final ArchiveEntry entry;
  final List<Operation> operations;
  final ValueChanged<bool>? onSelectionChanged;
  final bool checkboxesEnabled;
  const ArchiveTable({
    super.key,
    required this.entry,
    required this.operations,
    this.onSelectionChanged,
    this.checkboxesEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppConfig.cardBackgroundColor,
            borderRadius: AppConfig.largeBorderRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Серийный номер: ${context.read<MainData>().deviceInfo.serialNum}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 20),
              Text(
                'Гос номер: ${context.read<MainData>().deviceInfo.gosNum}',
                style: const TextStyle(fontSize: 18),
              ),
              BlocBuilder<TransferCubit, TransferState>(
                builder: (context, state) {
                  final hasError = operations.isNotEmpty &&
                      operations.every((op) => op.unavailable || op.checkError);
                  if (hasError) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 5.0),
                      child: Text(
                        'Нет связи с сервером.',
                        style: TextStyle(
                            color: AppConfig.errorColor, fontSize: 16),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Header with checkbox
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              _checkbox(
                _allSelected(operations),
                checkboxesEnabled
                    ? (v) {
                        final newValue = v ?? false;
                        final updatedOps = operations.map((op) {
                          final canToggle =
                              !op.unavailable && !op.exported && op.canSend;
                          return Operation(
                            dt: op.dt,
                            dtStop: op.dtStop,
                            maxP: op.maxP,
                            idOrg: op.idOrg,
                            workType: op.workType,
                            ngdu: op.ngdu,
                            field: op.field,
                            section: op.section,
                            bush: op.bush,
                            hole: op.hole,
                            brigade: op.brigade,
                            lat: op.lat,
                            lon: op.lon,
                            equipment: op.equipment,
                            pCnt: op.pCnt,
                            points: op.points,
                          )
                            ..selected = canToggle ? newValue : op.selected
                            ..canSend = op.canSend
                            ..checkError = op.checkError
                            ..exported = op.exported
                            ..unavailable = op.unavailable;
                        }).toList();
                        onSelectionChanged
                            ?.call(updatedOps.any((op) => op.selected));
                        BlocProvider.of<TransferCubit>(context)
                            .updateOperations(updatedOps);
                      }
                    : null,
                enabled: checkboxesEnabled,
              ),
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
                          color: AppConfig.primaryTextColor,
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
                          color: AppConfig.primaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: Colors.black.withAlpha(74)),
        const SizedBox(height: 1),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: operations.length,
            separatorBuilder: (_, __) =>
                Container(height: 1, color: Colors.black.withAlpha(74)),
            itemBuilder: (_, index) {
              final op = operations[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    _checkbox(
                      op.selected,
                      (v) {
                        final updatedOps =
                            operations.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final o = entry.value;
                          if (idx == index) {
                            return Operation(
                              dt: o.dt,
                              dtStop: o.dtStop,
                              maxP: o.maxP,
                              idOrg: o.idOrg,
                              workType: o.workType,
                              ngdu: o.ngdu,
                              field: o.field,
                              section: o.section,
                              bush: o.bush,
                              hole: o.hole,
                              brigade: o.brigade,
                              lat: o.lat,
                              lon: o.lon,
                              equipment: o.equipment,
                              pCnt: o.pCnt,
                              points: o.points,
                            )
                              ..selected = v ?? false
                              ..canSend = o.canSend
                              ..checkError = o.checkError
                              ..exported = o.exported
                              ..unavailable = o.unavailable;
                          } else {
                            return o;
                          }
                        }).toList();
                        onSelectionChanged
                            ?.call(updatedOps.any((e) => e.selected));
                        BlocProvider.of<TransferCubit>(context)
                            .updateOperations(updatedOps);
                      },
                      enabled: checkboxesEnabled &&
                          !op.unavailable &&
                          !op.exported &&
                          op.canSend,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              _formatDate(DateTime.fromMillisecondsSinceEpoch(
                                  op.dt * 1000)),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppConfig.tableTextColor,
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
                                color: AppConfig.tableTextColor,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),

                          SizedBox(
                            width: 40,
                            height: 25,
                            child: BlocBuilder<TransferCubit, TransferState>(
                              builder: (context, state) {
                                return _buildExportStatus(op, state);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  bool _allSelected(List<Operation> ops) {
    if (ops.isEmpty) return false;
    return ops.every((op) => op.selected);
  }

  Widget _buildExportStatus(Operation op, TransferState state) {
    if (state is ExportingState && state.currentExportingOperationDt == op.dt) {
      return Tooltip(
        message: 'Операция экспортируется',
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppConfig.primaryColor,
            ),
          ),
        ),
        triggerMode: TooltipTriggerMode.tap,
      );
    } else if (op.exported) {
      return Tooltip(
        message: 'Операция успешно экспортирована',
        child: Icon(Icons.check_circle, color: Colors.green, size: 22),
        triggerMode: TooltipTriggerMode.tap,
      );
    } else if (op.unavailable || op.checkError) {
      String msg = op.unavailable
          ? 'нет связи или ошибка'
          : 'Ошибка при экспорте операции';
      if (op.errorCode != 0) {
        msg += '\nКод ошибки: ${op.errorCode}';
      }
      return Tooltip(
        message: msg,
        child: Icon(Icons.error, color: Colors.red, size: 22),
        triggerMode: TooltipTriggerMode.tap,
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
