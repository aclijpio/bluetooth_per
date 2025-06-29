import 'package:equatable/equatable.dart';

class TableRowData extends Equatable {
  final DateTime date;
  final String wellId;
  final String operationType;
  final int pointCount;
  final bool isSelected;

  const TableRowData({
    required this.date,
    required this.wellId,
    this.operationType = '',
    this.pointCount = 0,
    this.isSelected = false,
  });

  TableRowData copyWith({
    DateTime? date,
    String? wellId,
    String? operationType,
    int? pointCount,
    bool? isSelected,
  }) {
    return TableRowData(
      date: date ?? this.date,
      wellId: wellId ?? this.wellId,
      operationType: operationType ?? this.operationType,
      pointCount: pointCount ?? this.pointCount,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object?> get props =>
      [date, wellId, operationType, pointCount, isSelected];

  @override
  String toString() =>
      'TableRowData(date: $date, wellId: $wellId, pointCount: $pointCount)';
}
