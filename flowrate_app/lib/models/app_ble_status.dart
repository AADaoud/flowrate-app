enum AppBleStage {
  idle,
  scanning,
  connecting,
  connected,
  notifying,
  error,
  disconnected,
}

class AppBleStatus {
  final AppBleStage stage;
  final String message;

  const AppBleStatus(this.stage, this.message);

  @override
  String toString() {
    return "${stage.name.toUpperCase()}: $message";
  }
}
