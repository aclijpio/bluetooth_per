import '../entities/main_data.dart';
import '../entities/operation.dart';
import '../entities/point.dart';

/// Сервис для интеграции с веб-сервером
class WebIntegrationService {
  final MainData _mainData;

  WebIntegrationService(this._mainData);

  /// Загружает операции из распакованного архива
  Future<OperStatus> loadOperationsFromArchive(String archivePath) async {
    try {
      _mainData.dbPath = archivePath;
      return await _mainData.awaitOperations();
    } catch (e) {
      return OperStatus.dbError;
    }
  }

  /// Получает список операций
  List<Operation> getOperations() {
    // Конвертируем старые операции в новые (без точек)
    return _mainData.operations
        .map((oldOp) => _convertToNewOperation(oldOp))
        .toList();
  }

  /// Загружает точки для операции
  Future<OperStatus> loadOperationPoints(Operation operation) async {
    // Конвертируем новую операцию в старую для совместимости
    final oldOperation = _convertToOldOperation(operation);
    return await _mainData.awaitOperationPoints(oldOperation);
  }

  /// Проверяет статус отправки операций
  Future<OperStatus> checkOperationsSendStatus() async {
    return await _mainData.awaitOperationsCanSendStatus();
  }

  /// Отправляет операцию на сервер
  Future<int> sendOperation(Operation operation) async {
    // Конвертируем новую операцию в старую для совместимости
    final oldOperation = _convertToOldOperation(operation);
    return await _mainData.awaitSendingOperation(oldOperation);
  }

  /// Сравнивает точки и возвращает отличающиеся
  List<Point> getDifferentPoints(Operation operation) {
    // Здесь должна быть логика сравнения точек
    // Пока возвращаем все точки операции
    return operation.points;
  }

  /// Отправляет отличающиеся точки на сервер
  Future<int> sendDifferentPoints(List<Point> points) async {
    // Здесь должна быть логика отправки точек
    // Пока возвращаем успешный статус
    return 200;
  }

  /// Сбрасывает данные операций
  void resetOperationData() {
    _mainData.resetOperationData();
  }

  /// Конвертирует старую операцию в новую (без точек)
  Operation _convertToNewOperation(Operation oldOp) {
    return Operation(
      dt: oldOp.dt,
      dtStop: oldOp.dtStop,
      maxP: oldOp.maxP,
      idOrg: oldOp.idOrg,
      workType: oldOp.workType,
      ngdu: oldOp.ngdu,
      field: oldOp.field,
      section: oldOp.section,
      bush: oldOp.bush,
      hole: oldOp.hole,
      brigade: oldOp.brigade,
      lat: oldOp.lat,
      lon: oldOp.lon,
      equipment: oldOp.equipment,
      pCnt: oldOp.pCnt,
      points: [], // Точки будут загружены отдельно
    );
  }

  /// Конвертирует новую операцию в старую (без точек)
  Operation _convertToOldOperation(Operation newOp) {
    return Operation(
      dt: newOp.dt,
      dtStop: newOp.dtStop,
      maxP: newOp.maxP,
      idOrg: newOp.idOrg,
      workType: newOp.workType,
      ngdu: newOp.ngdu,
      field: newOp.field,
      section: newOp.section,
      bush: newOp.bush,
      hole: newOp.hole,
      brigade: newOp.brigade,
      lat: newOp.lat,
      lon: newOp.lon,
      equipment: newOp.equipment,
      pCnt: newOp.pCnt,
      points: [], // Точки будут загружены отдельно
    );
  }
}
