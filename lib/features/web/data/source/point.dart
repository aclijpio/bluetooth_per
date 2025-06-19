import 'package:flutter/foundation.dart';
import 'package:convert/convert.dart';

class Point {
  int dt;
  double lat;
  double lon;
  int speed;
  String binValue;

  Point({
    required this.dt,
    required this.lat,
    required this.lon,
    required this.speed,
    required this.binValue,
  });

  factory Point.fromMap(Map<String, Object?> map) {
    Uint8List blob = map['point'] as Uint8List;
    return Point(
      dt: map['date'] as int ?? 0,
      lat: map['lat'] as double ?? 0.0,
      lon: map['lon'] as double ?? 0.0,
      speed: map['speed'] as int ?? 0,
      binValue: hex.encode(blob),
    );
  }

  Map<String, dynamic> toSendMap() {
    return {
      "d": dt,
      "t": lat,
      "n": lon,
      "s": speed,
      "v": binValue,
    };
  }
}
