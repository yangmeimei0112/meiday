import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/kickout_event.dart';
import 'session_realtime_datasource.dart';

class SupabaseSessionRealtimeDataSource implements SessionRealtimeDataSource {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController<KickoutEvent>> _controllers = {};

  SupabaseSessionRealtimeDataSource([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<KickoutEvent> subscribeToKickout(String userId) {
    if (_controllers.containsKey(userId)) {
      return _controllers[userId]!.stream;
    }

    final controller = StreamController<KickoutEvent>.broadcast();
    _controllers[userId] = controller;

    final channel = _client.channel('user_sessions:$userId');
    _channels[userId] = channel;

    channel.onBroadcast(event: 'kickout', callback: (payload) {
      final event = KickoutEvent(
        userId: payload['user_id'] as String? ?? userId,
        targetDeviceId: payload['target_device_id'] as String?,
        excludedDeviceId: payload['excluded_device_id'] as String?,
        reason: payload['reason'] as String? ?? 'Remotely logged out',
        timestamp: payload['timestamp'] != null
            ? DateTime.parse(payload['timestamp'] as String)
            : DateTime.now(),
      );
      controller.add(event);
    }).subscribe();

    return controller.stream;
  }

  @override
  Future<void> broadcastKickout(KickoutEvent event) async {
    final channel = _channels[event.userId] ?? _client.channel('user_sessions:${event.userId}');
    await channel.sendBroadcastMessage(
      event: 'kickout',
      payload: {
        'user_id': event.userId,
        'target_device_id': event.targetDeviceId,
        'excluded_device_id': event.excludedDeviceId,
        'reason': event.reason,
        'timestamp': event.timestamp.toIso8601String(),
      },
    );
  }

  @override
  Future<void> unsubscribe(String userId) async {
    final channel = _channels.remove(userId);
    if (channel != null) {
      await _client.removeChannel(channel);
    }
    final controller = _controllers.remove(userId);
    if (controller != null) {
      await controller.close();
    }
  }
}
