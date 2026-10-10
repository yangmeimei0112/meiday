import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_device.dart';
import '../../domain/repositories/session_registry_repository.dart';

class SessionRegistryNotifier extends StateNotifier<AsyncValue<List<UserDevice>>> {
  final SessionRegistryRepository _repository;
  final String _userId;

  SessionRegistryNotifier(this._repository, this._userId) : super(const AsyncValue.loading()) {
    _listen();
  }

  void _listen() {
    _repository.watchActiveDevices(userId: _userId).listen(
      (devices) => state = AsyncValue.data(devices),
      onError: (e, st) => state = AsyncValue.error(e, st),
    );
  }

  Future<void> refresh() async {
    await _repository.refreshActiveDevices(userId: _userId);
  }

  Future<void> kickDevice(String deviceId) async {
    await _repository.kickDevice(deviceId: deviceId, userId: _userId);
  }

  Future<void> kickAllOtherDevices(String currentDeviceId) async {
    await _repository.kickAllOtherDevices(
      currentDeviceId: currentDeviceId,
      userId: _userId,
    );
  }
}
