/// Ответ с списком операций (старый API для совместимости)
class OperListResponse {
  final int resultCode;
  final List<int> operDtList;

  OperListResponse(this.resultCode, this.operDtList);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OperListResponse &&
        other.resultCode == resultCode &&
        other.operDtList == operDtList;
  }

  @override
  int get hashCode => resultCode.hashCode ^ operDtList.hashCode;

  @override
  String toString() {
    return 'OperListResponse(resultCode: $resultCode, operDtList: $operDtList)';
  }
}
