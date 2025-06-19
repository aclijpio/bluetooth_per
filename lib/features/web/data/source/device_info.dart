import 'package:flutter/foundation.dart';

class DeviceInfo {
  final String serialNum;
  final String gosNum;

  DeviceInfo({required this.serialNum, required this.gosNum});

  factory DeviceInfo.fromMap(Map<String, Object?> map) {
    return DeviceInfo(
      serialNum: map['serNumber'].toString() ?? '',
      gosNum: map['stNumber'].toString() ?? '',
    );
  }

  factory DeviceInfo.empty() {
    return DeviceInfo(serialNum: '', gosNum: '');
  }
}
