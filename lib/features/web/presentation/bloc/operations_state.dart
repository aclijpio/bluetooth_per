abstract class OperationsState {}

class EmptyOperationsState extends OperationsState {}

class LoadingOperationsState extends OperationsState {}

class LoadedOperationsState extends OperationsState {}

class ErrorOperationsState extends OperationsState {
  final int errorCode;

  ErrorOperationsState(this.errorCode);
}
