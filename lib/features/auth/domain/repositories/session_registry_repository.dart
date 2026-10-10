import '../entities/user_device.dart';
import '../entities/kickout_event.dart';

abstract class SessionRegistryRepository {
  Future<UserDevice> registerCurrentDevice({required String userId});
  Stream<List<UserDevice>> watchActiveDevices({required String userId});
  Future<void> refreshActiveDevices({required String userId});
  Future<void> kickDevice({required String deviceId, required String userId});
  Future<void> kickAllOtherDevices({required String currentDeviceId, required String userId});
  Stream<KickoutEvent> watchRemoteKickout({required String userId});
  Future<String> getCurrentDeviceId();
}
