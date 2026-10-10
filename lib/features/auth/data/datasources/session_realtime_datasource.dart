import '../../domain/entities/kickout_event.dart';

abstract class SessionRealtimeDataSource {
  Stream<KickoutEvent> subscribeToKickout(String userId);
  Future<void> broadcastKickout(KickoutEvent event);
  Future<void> unsubscribe(String userId);
}
