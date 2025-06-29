import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';

/// Сущность точки с данными
class Point {
  final int dt;
  final double lat;
  final double lon;
  final int speed;
  final String binValue;

  const Point({
    required this.dt,
    required this.lat,
    required this.lon,
    required this.speed,
    required this.binValue,
  });

  factory Point.fromMap(Map<String, Object?> map) {
    final pointData = map['point'];
    if (pointData == null) {
      throw ArgumentError('Point data is null');
    }

    Uint8List blob = pointData as Uint8List;
    return Point(
      dt: map['date'] as int? ?? 0,
      lat: map['lat'] as double? ?? 0.0,
      lon: map['lon'] as double? ?? 0.0,
      speed: map['speed'] as int? ?? 0,
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Point &&
        other.dt == dt &&
        other.lat == lat &&
        other.lon == lon &&
        other.speed == speed &&
        other.binValue == binValue;
  }

  @override
  int get hashCode {
    return dt.hashCode ^
        lat.hashCode ^
        lon.hashCode ^
        speed.hashCode ^
        binValue.hashCode;
  }

  @override
  String toString() {
    return 'Point(dt: $dt, lat: $lat, lon: $lon, speed: $speed, binValue: $binValue)';
  }
}
