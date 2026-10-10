import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashUtils {
  /// Computes a standard SHA-256 hash formatted as a lowercase hexadecimal string (64 characters).
  static String sha256Hex(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Computes the isolated physical SQLite database filename:
  /// - If [userId] is null, empty, or whitespace -> 'guest.db'
  /// - If [userId] is present -> 'user_${sha256Hex(userId.trim())}.db' (72 chars total)
  static String resolveDatabaseName(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return 'guest.db';
    }
    final hash = sha256Hex(userId.trim());
    return 'user_$hash.db';
  }

  /// Computes the isolated physical SQLite database filename for a given user ID.
  /// Harmonized with resolveDatabaseName: always returns 72-character 'user_<64-char-hex>.db'.
  static String userDbFileName(String userId) {
    return resolveDatabaseName(userId);
  }
}
