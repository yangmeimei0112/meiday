import 'package:uuid/uuid.dart';

class UuidUtils {
  static const _uuid = Uuid();

  /// Generates a canonical RFC4122 v4 UUID string.
  static String generate() => _uuid.v4();
}
