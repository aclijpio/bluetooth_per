import 'point.dart';

/// Сущность операции
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
      dt: map['DT'] as int? ?? 0,
      dtStop: 0,
      maxP: map['max_pressure'] as int? ?? 0,
      idOrg: map['Organization'] as int? ?? 0,
      workType: map['work_type'] as int? ?? 0,
      ngdu: map['NGDU'].toString(),
      field: map['Field'].toString(),
      section: map['Department'].toString(),
      bush: map['Cluster'].toString(),
      hole: map['Hole'].toString(),
      brigade: map['brigade'].toString(),
      lat: map['lat'] as double? ?? 0.0,
      lon: map['lon'] as double? ?? 0.0,
      equipment: map['equipment'] as int? ?? 0,
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Operation &&
        other.dt == dt &&
        other.dtStop == dtStop &&
        other.maxP == maxP &&
        other.idOrg == idOrg &&
        other.workType == workType &&
        other.ngdu == ngdu &&
        other.field == field &&
        other.section == section &&
        other.bush == bush &&
        other.hole == hole &&
        other.brigade == brigade &&
        other.lat == lat &&
        other.lon == lon &&
        other.equipment == equipment &&
        other.pCnt == pCnt &&
        other.selected == selected &&
        other.canSend == canSend;
  }

  @override
  int get hashCode {
    return dt.hashCode ^
        dtStop.hashCode ^
        maxP.hashCode ^
        idOrg.hashCode ^
        workType.hashCode ^
        ngdu.hashCode ^
        field.hashCode ^
        section.hashCode ^
        bush.hashCode ^
        hole.hashCode ^
        brigade.hashCode ^
        lat.hashCode ^
        lon.hashCode ^
        equipment.hashCode ^
        pCnt.hashCode ^
        selected.hashCode ^
        canSend.hashCode;
  }

  @override
  String toString() {
    return 'Operation(dt: $dt, ngdu: $ngdu, field: $field, hole: $hole, selected: $selected, canSend: $canSend)';
  }
}
