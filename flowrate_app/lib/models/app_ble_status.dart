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
  final DateTime timestamp;

  AppBleStatus(this.stage, this.message, {DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  bool get isError => stage == AppBleStage.error;
  bool get isReady => stage == AppBleStage.notifying;

  AppBleStatus copyWith({AppBleStage? stage, String? message}) {
    return AppBleStatus(
      stage ?? this.stage,
      message ?? this.message,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return "${stage.name.toUpperCase()}: $message";
  }
}
