import 'calendar_command.dart';

class CompositeCalendarCommand implements CalendarCommand {
  @override
  final String id;
  @override
  final String description;
  @override
  final DateTime timestamp;

  final List<CalendarCommand> commands;

  CompositeCalendarCommand({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.commands,
  });

  @override
  Future<void> execute() async {
    for (final cmd in commands) {
      await cmd.execute();
    }
  }

  @override
  Future<void> undo() async {
    for (final cmd in commands.reversed) {
      await cmd.undo();
    }
  }

  @override
  Future<void> redo() async {
    for (final cmd in commands) {
      await cmd.redo();
    }
  }
}
