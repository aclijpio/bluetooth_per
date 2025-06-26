import 'package:flutter/material.dart';

import '../bloc/device_flow_state.dart';
import '../models/archive_entry.dart';

class ArchiveTable extends StatefulWidget {
  final ArchiveEntry entry;
  final List<TableRowData> rows;
  final ValueChanged<bool>? onSelectionChanged;
  const ArchiveTable({
    super.key,
    required this.entry,
    required this.rows,
    this.onSelectionChanged,
  });

  @override
  State<ArchiveTable> createState() => _ArchiveTableState();
}

class _ArchiveTableState extends State<ArchiveTable> {
  late List<bool> selected;
  bool selectAll = false;

  @override
  void initState() {
    super.initState();
    selected = List<bool>.filled(widget.rows.length, false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSelectionChanged?.call(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info container
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F2FA),
            borderRadius: BorderRadius.circular(27),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.entry.fileName,
                style: const TextStyle(fontSize: 24, color: Color(0xFF222222)),
              ),
              const SizedBox(height: 25),
              const Text(
                'Серийный номер прибора:',
                style: TextStyle(fontSize: 20, color: Color(0xFF424242)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Гос. номер агрегата:',
                style: TextStyle(fontSize: 20, color: Color(0xFF424242)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        // Header with checkbox
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          child: Row(
            children: [
              _checkbox(selectAll, (v) {
                setState(() {
                  selectAll = v ?? false;
                  for (int i = 0; i < selected.length; i++) {
                    selected[i] = selectAll;
                  }
                });
                widget.onSelectionChanged?.call(selected.any((e) => e));
              }),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: const [
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
        ),
        Container(height: 1, color: Colors.black.withAlpha(74)),
        const SizedBox(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: widget.rows.length,
            separatorBuilder: (_, __) =>
                Container(height: 1, color: Colors.black.withAlpha(74)),
            itemBuilder: (_, index) {
              final row = widget.rows[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 21,
                ),
                child: Row(
                  children: [
                    _checkbox(selected[index], (v) {
                      setState(() {
                        selected[index] = v ?? false;
                        selectAll = selected.every((e) => e);
                      });
                      widget.onSelectionChanged?.call(selected.any((e) => e));
                    }),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              _formatDate(row.date),
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
                              row.wellId,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF484848),
                                overflow: TextOverflow.ellipsis,
                              ),
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

  Widget _checkbox(bool value, ValueChanged<bool?> onChanged) {
    return SizedBox(
      width: 33,
      height: 33,
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
