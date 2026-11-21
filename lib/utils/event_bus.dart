import 'dart:async';

class AppEvent {
  final String type;
  final Map<String, dynamic> data;
  AppEvent(this.type, [this.data = const {}]);
}

class EventBus {
  static final EventBus instance = EventBus._internal();
  EventBus._internal();

  final _controller = StreamController<AppEvent>.broadcast();
  Stream<AppEvent> get stream => _controller.stream;

  void emit(AppEvent e) => _controller.add(e);
  void dispose() => _controller.close();
}

// أنواع الأحداث
const String kTargetSentEvent = 'target_sent';