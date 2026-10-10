import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/user_device_dao.dart';
import '../../domain/entities/kickout_event.dart';
import '../../domain/entities/user_device.dart';
import '../../domain/repositories/session_registry_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/session_realtime_datasource.dart';
import '../models/user_device_model.dart';

class SessionRegistryRepositoryImpl implements SessionRegistryRepository {
  final UserDeviceDao? _staticDeviceDao;
  final UserDeviceDao Function()? _deviceDaoProvider;
  final AuthRemoteDataSource _remoteDataSource;
  final SessionRealtimeDataSource _realtimeDataSource;
  final AuthLocalDataSource _localDataSource;

  SessionRegistryRepositoryImpl({
    UserDeviceDao? deviceDao,
    UserDeviceDao Function()? deviceDaoProvider,
    required AuthRemoteDataSource remoteDataSource,
    required SessionRealtimeDataSource realtimeDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _staticDeviceDao = deviceDao,
        _deviceDaoProvider = deviceDaoProvider,
        _remoteDataSource = remoteDataSource,
        _realtimeDataSource = realtimeDataSource,
        _localDataSource = localDataSource;

  UserDeviceDao get _deviceDao => _deviceDaoProvider != null ? _deviceDaoProvider() : _staticDeviceDao!;

  @override
  Future<String> getCurrentDeviceId() {
    return _localDataSource.getOrCreateDeviceId();
  }

  @override
  Future<UserDevice> registerCurrentDevice({required String userId}) async {
    final deviceId = await getCurrentDeviceId();
    final platformName = _resolvePlatformName();
    final deviceName = _resolveDeviceName(platformName);
    final now = DateTime.now();

    final companion = UserDevicesCompanion.insert(
      id: deviceId,
      userId: userId,
      deviceName: deviceName,
      platform: platformName,
      deviceToken: 'device_token_$deviceId',
      lastActiveAt: now,
      isCurrent: const Value(true),
      createdAt: now,
    );

    await _deviceDao.upsertDevice(companion);

    final device = UserDevice(
      id: deviceId,
      userId: userId,
      deviceName: deviceName,
      platform: platformName,
      deviceToken: 'device_token_$deviceId',
      lastActiveAt: now,
      isCurrent: true,
      createdAt: now,
    );

    try {
      await _remoteDataSource.upsertDevice(device);
    } catch (_) {}

    return device;
  }

  @override
  Stream<List<UserDevice>> watchActiveDevices({required String userId}) {
    return _deviceDao.watchDevices().map((list) {
      return list.map(UserDeviceModel.fromData).toList();
    });
  }

  @override
  Future<void> refreshActiveDevices({required String userId}) async {
    try {
      final remoteList = await _remoteDataSource.fetchDevices(userId);
      final currentId = await getCurrentDeviceId();

      for (final rDev in remoteList) {
        final isCurrent = rDev.id == currentId;
        await _deviceDao.upsertDevice(
          UserDevicesCompanion.insert(
            id: rDev.id,
            userId: rDev.userId,
            deviceName: rDev.deviceName,
            platform: rDev.platform,
            deviceToken: rDev.deviceToken,
            lastActiveAt: rDev.lastActiveAt,
            clientIp: Value(rDev.clientIp),
            isCurrent: Value(isCurrent),
            createdAt: rDev.createdAt,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Future<void> kickDevice({required String deviceId, required String userId}) async {
    await _deviceDao.removeDevice(deviceId);
    try {
      await _remoteDataSource.removeDevice(deviceId);
    } catch (_) {}

    await _realtimeDataSource.broadcastKickout(
      KickoutEvent(
        userId: userId,
        targetDeviceId: deviceId,
        reason: 'Session terminated by another device',
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> kickAllOtherDevices({
    required String currentDeviceId,
    required String userId,
  }) async {
    final devices = await _deviceDao.watchDevices().first;
    for (final d in devices) {
      if (d.id != currentDeviceId) {
        await _deviceDao.removeDevice(d.id);
        try {
          await _remoteDataSource.removeDevice(d.id);
        } catch (_) {}
      }
    }

    await _realtimeDataSource.broadcastKickout(
      KickoutEvent(
        userId: userId,
        targetDeviceId: null,
        excludedDeviceId: currentDeviceId,
        reason: 'All other sessions were logged out remotely',
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Stream<KickoutEvent> watchRemoteKickout({required String userId}) {
    return _realtimeDataSource.subscribeToKickout(userId);
  }

  String _resolvePlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  String _resolveDeviceName(String platform) {
    if (kIsWeb) return 'Web Browser';
    try {
      final host = Platform.localHostname;
      if (host.isNotEmpty) return '$host ($platform)';
    } catch (_) {}
    return 'ChronoHub $platform Terminal';
  }
}
