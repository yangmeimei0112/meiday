import 'dart:async';
import '../../domain/entities/kickout_event.dart';
import 'session_realtime_datasource.dart';

class MockSessionRealtimeDataSource implements SessionRealtimeDataSource {
  final StreamController<KickoutEvent> _controller = StreamController<KickoutEvent>.broadcast();

  @override
  Stream<KickoutEvent> subscribeToKickout(String userId) {
    return _controller.stream.where((event) => event.userId == userId);
  }

  @override
  Future<void> broadcastKickout(KickoutEvent event) async {
    _controller.add(event);
  }

  @override
  Future<void> unsubscribe(String userId) async {
    // No-op for mock
  }

  void simulateRemoteKick(KickoutEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}
