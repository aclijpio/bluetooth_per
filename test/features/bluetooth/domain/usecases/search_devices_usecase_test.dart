import 'package:bluetooth_per/core/error/failures.dart';
import 'package:bluetooth_per/core/usecases/usecase.dart';
import 'package:bluetooth_per/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:bluetooth_per/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:bluetooth_per/features/bluetooth/domain/usecases/search_devices_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'search_devices_usecase_test.mocks.dart';

@GenerateMocks([BluetoothRepository])
void main() {
  late SearchDevicesUseCase useCase;
  late MockBluetoothRepository mockRepository;

  setUp(() {
    mockRepository = MockBluetoothRepository();
    useCase = SearchDevicesUseCase(mockRepository);
  });

  group('SearchDevicesUseCase', () {
    const tDevices = [
      BluetoothDeviceEntity(
        address: '00:11:22:33:44:55',
        name: 'Quantor A123BC',
      ),
      BluetoothDeviceEntity(
        address: '00:11:22:33:44:56',
        name: 'Quantor B456DE',
      ),
    ];

    test('should return list of devices when search is successful', () async {
      // arrange
      when(mockRepository.searchDevices())
          .thenAnswer((_) async => const Right(tDevices));

      // act
      final result = await useCase(const NoParams());

      // assert
      expect(result, const Right(tDevices));
      verify(mockRepository.searchDevices());
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return BluetoothFailure when search fails', () async {
      // arrange
      const tFailure = BluetoothFailure(
        message: 'Bluetooth search failed',
        code: 'BT_SEARCH_FAILED',
      );
      when(mockRepository.searchDevices())
          .thenAnswer((_) async => const Left(tFailure));

      // act
      final result = await useCase(const NoParams());

      // assert
      expect(result, const Left(tFailure));
      verify(mockRepository.searchDevices());
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return empty list when no devices found', () async {
      // arrange
      when(mockRepository.searchDevices())
          .thenAnswer((_) async => const Right([]));

      // act
      final result = await useCase(const NoParams());

      // assert
      expect(result, const Right([]));
      verify(mockRepository.searchDevices());
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return BluetoothNotEnabledFailure when Bluetooth is disabled', () async {
      // arrange
      const tFailure = BluetoothNotEnabledFailure();
      when(mockRepository.searchDevices())
          .thenAnswer((_) async => const Left(tFailure));

      // act
      final result = await useCase(const NoParams());

      // assert
      expect(result, const Left(tFailure));
      verify(mockRepository.searchDevices());
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return BluetoothPermissionFailure when permissions denied', () async {
      // arrange
      const tFailure = BluetoothPermissionFailure();
      when(mockRepository.searchDevices())
          .thenAnswer((_) async => const Left(tFailure));

      // act
      final result = await useCase(const NoParams());

      // assert
      expect(result, const Left(tFailure));
      verify(mockRepository.searchDevices());
      verifyNoMoreInteractions(mockRepository);
    });
  });
}