import 'package:flutter_bloc/flutter_bloc.dart';

class ExportProgressState {
  final double progress; // 0.0 - 1.0
  final bool isExporting;

  ExportProgressState({required this.progress, required this.isExporting});

  ExportProgressState copyWith({double? progress, bool? isExporting}) =>
      ExportProgressState(
        progress: progress ?? this.progress,
        isExporting: isExporting ?? this.isExporting,
      );
}

class ExportProgressCubit extends Cubit<ExportProgressState> {
  ExportProgressCubit()
      : super(ExportProgressState(progress: 0, isExporting: false));

  void start() => emit(ExportProgressState(progress: 0, isExporting: true));
  void update(double progress) => emit(ExportProgressState(progress: progress, isExporting: true));
  void finish() => emit(ExportProgressState(progress: 1, isExporting: false));
  void reset() => emit(ExportProgressState(progress: 0, isExporting: false));
}
