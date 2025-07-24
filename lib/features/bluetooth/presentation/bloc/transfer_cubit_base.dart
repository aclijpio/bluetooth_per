import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import '../../../../core/data/main_data.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../domain/repositories/bluetooth_repository.dart';
import '../models/device.dart';
import 'transfer_state.dart';

/// Base class for TransferCubit providing common functionality
abstract class TransferCubitBase extends Cubit<TransferState> {
  final BluetoothRepository repository;
  final MainData mainData;
  final Logger logger;
  final List<Device> lastFoundDevices = [];
  bool searching = false;

  TransferCubitBase(this.repository, this.mainData)
      : logger = di.sl<Logger>(),
        super(const InitialSearchState());

  /// Format transfer speed for display
  String formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    }
    final kB = bytesPerSec / 1024;
    if (kB < 1024) return '${kB.toStringAsFixed(1)} KB/s';
    final mB = kB / 1024;
    return '${mB.toStringAsFixed(1)} MB/s';
  }

  /// Common error handling for all cubit operations
  void handleError(Object error, StackTrace stackTrace, String operation) {
    logger.e('Error in $operation: $error', error: error, stackTrace: stackTrace);
    emit(ErrorState('Произошла ошибка в $operation: ${error.toString()}'));
  }

  /// Common state transition logging
  void logStateTransition(TransferState newState) {
    logger.d('State transition: ${state.runtimeType} -> ${newState.runtimeType}');
  }

  @override
  void emit(TransferState state) {
    logStateTransition(state);
    super.emit(state);
  }

  @override
  Future<void> close() {
    logger.d('Closing TransferCubit');
    return super.close();
  }
}