abstract class SendingState {
  double percent;

  SendingState(this.percent);
}

class StopSendingState extends SendingState {
  StopSendingState(super.percent);
}

class ProcessingSendingState extends SendingState {
  ProcessingSendingState(super.percent);
}

class ErrorSendingState extends SendingState {
  int errorCode;

  ErrorSendingState(super.percent, this.errorCode);
}
