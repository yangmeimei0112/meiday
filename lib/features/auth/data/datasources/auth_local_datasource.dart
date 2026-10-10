import 'dart:convert';
import '../../../../core/platform/secure_storage_service.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../domain/entities/auth_session.dart';
import '../models/auth_session_model.dart';

class AuthLocalDataSource {
  final SecureStorageService _storage;
  static const String keySession = 'chronohub_auth_session';
  static const String keyDeviceId = 'chronohub_device_id';

  AuthLocalDataSource(this._storage);

  Future<void> saveSession(AuthSession session) async {
    final jsonStr = jsonEncode(AuthSessionModel.fromDomain(session).toJson());
    await _storage.write(key: keySession, value: jsonStr);
  }

  Future<AuthSession?> getSession() async {
    final jsonStr = await _storage.read(key: keySession);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AuthSessionModel.fromJson(map).toDomain();
    } catch (_) {
      await _storage.delete(key: keySession);
      return null;
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(key: keySession);
  }

  Future<String> getOrCreateDeviceId() async {
    var id = await _storage.read(key: keyDeviceId);
    if (id == null || id.isEmpty) {
      id = UuidUtils.generate();
      await _storage.write(key: keyDeviceId, value: id);
    }
    return id;
  }
}
