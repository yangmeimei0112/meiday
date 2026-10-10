import 'package:meta/meta.dart';

@immutable
abstract class CalendarCommand {
  /// Unique identifier of this command instance (UUID v4).
  String get id;

  /// User-facing, localized description of the operation (e.g. "Move 'Meeting' to 10:00").
  String get description;

  /// Timestamp when the command was initially created.
  DateTime get timestamp;

  /// Executes the mutation against the SQLite database and sync outbox.
  Future<void> execute();

  /// Reverts the mutation atomically.
  Future<void> undo();

  /// Re-applies the mutation atomically after an undo.
  Future<void> redo();
}
