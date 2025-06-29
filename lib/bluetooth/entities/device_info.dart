/// Информация об устройстве
class DeviceInfo {
  final String serialNum;
  final String gosNum;

  const DeviceInfo({
    required this.serialNum,
    required this.gosNum,
  });

  factory DeviceInfo.fromMap(Map<String, Object?> map) {
    return DeviceInfo(
      serialNum: map['serNumber'].toString(),
      gosNum: map['stNumber'].toString(),
    );
  }

  factory DeviceInfo.empty() {
    return const DeviceInfo(serialNum: '', gosNum: '');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceInfo &&
        other.serialNum == serialNum &&
        other.gosNum == gosNum;
  }

  @override
  int get hashCode => serialNum.hashCode ^ gosNum.hashCode;

  @override
  String toString() {
    return 'DeviceInfo(serialNum: $serialNum, gosNum: $gosNum)';
  }
}
