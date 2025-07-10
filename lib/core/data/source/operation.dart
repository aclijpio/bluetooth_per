import 'package:bluetooth_per/core/data/source/point.dart';

class Operation {
  int dt;
  int dtStop;
  int maxP;
  int idOrg;
  int workType;
  String ngdu;
  String field;
  String section;
  String bush;
  String hole;
  String brigade;
  double lat;
  double lon;
  int equipment;
  int pCnt;
  List<Point> points;

  bool selected = false;
  bool canSend = false;
  bool checkError = false; // Ошибка при проверке на сервере
  bool exported = false; // Успешно экспортирована
  bool unavailable =
      false; // Недоступна для экспорта (нет связи, ошибка и т.д.)

  int errorCode = 0; // Код ошибки экспорта, если есть

  Operation({
    required this.dt,
    required this.dtStop,
    required this.maxP,
    required this.idOrg,
    required this.workType,
    required this.ngdu,
    required this.field,
    required this.section,
    required this.bush,
    required this.hole,
    required this.brigade,
    required this.lat,
    required this.lon,
    required this.equipment,
    required this.pCnt,
    required this.points,
  });

  factory Operation.fromMap(Map<String, Object?> map) {
    return Operation(
      dt: map['DT'] as int ?? 0,
      dtStop: 0,
      maxP: map['max_pressure'] as int ?? 0,
      idOrg: map['Organization'] as int ?? 0,
      workType: map['work_type'] as int ?? 0,
      ngdu: map['NGDU'].toString() ?? '',
      field: map['Field'].toString() ?? '',
      section: map['Department'].toString() ?? '',
      bush: map['Cluster'].toString() ?? '',
      hole: map['Hole'].toString() ?? '',
      brigade: map['brigade'].toString() ?? '',
      lat: map['lat'] as double ?? 0.0,
      lon: map['lon'] as double ?? 0.0,
      equipment: map['equipment'] as int ?? 0,
      pCnt: 0,
      points: [],
    );
  }

  Map<String, dynamic> dtAndCount() {
    return {
      'd': dt,
      'p': pCnt,
    };
  }

  Map<String, dynamic> toSendMap() {
    return {
      "dt": dt,
      "maxP": maxP,
      "idOrg": idOrg,
      "workType": workType,
      "ngdu": ngdu,
      "field": field,
      "section": section,
      "bush": bush,
      "hole": hole,
      "brigade": brigade,
      "lat": lat,
      "lon": lon,
      "equipment": equipment,
      "pCnt": pCnt,
    };
  }
}
