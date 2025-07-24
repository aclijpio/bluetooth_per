import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/bluetooth_device.dart';
import '../repositories/bluetooth_repository.dart';

class SearchDevicesUseCase implements UseCase<List<BluetoothDeviceEntity>, NoParams> {
  final BluetoothRepository repository;

  SearchDevicesUseCase(this.repository);

  @override
  Future<Either<Failure, List<BluetoothDeviceEntity>>> call(NoParams params) async {
    return await repository.searchDevices();
  }
}

class SearchDevicesParams {
  final Duration timeout;
  final bool filterQuantorDevices;

  const SearchDevicesParams({
    required this.timeout,
    this.filterQuantorDevices = true,
  });
}