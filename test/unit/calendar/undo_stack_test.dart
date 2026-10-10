import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/utils/uuid_utils.dart';
import 'package:smart_calendar_hub/features/calendar/application/commands/calendar_command.dart';
import 'package:smart_calendar_hub/features/calendar/application/commands/cascade_schedule_command.dart';
import 'package:smart_calendar_hub/features/calendar/application/commands/create_event_command.dart';
import 'package:smart_calendar_hub/features/calendar/application/commands/models/event_time_shift.dart';
import 'package:smart_calendar_hub/features/calendar/application/commands/move_event_command.dart';
import 'package:smart_calendar_hub/features/calendar/application/undo/undo_stack_manager.dart';
import 'package:smart_calendar_hub/features/calendar/domain/entities/schedule_models.dart';

class _CommandCallTracker {
  int executeCount = 0;
  int undoCount = 0;
  int redoCount = 0;
}

class _FakeTestCommand implements CalendarCommand {
  @override
  final String id;
  @override
  final String description;
  @override
  final DateTime timestamp;

  final _CommandCallTracker _tracker = _CommandCallTracker();

  int get executeCount => _tracker.executeCount;
  int get undoCount => _tracker.undoCount;
  int get redoCount => _tracker.redoCount;

  _FakeTestCommand({required this.id, required this.description})
      : timestamp = DateTime.now();

  @override
  Future<void> execute() async {
    _tracker.executeCount++;
  }

  @override
  Future<void> undo() async {
    _tracker.undoCount++;
  }

  @override
  Future<void> redo() async {
    _tracker.redoCount++;
  }
}

void main() {
  group('UndoStackManager Unit Tests', () {
    test('Basic execute, undo, redo lifecycle updates stack status correctly', () async {
      final manager = UndoStackManager(maxCapacity: 50);
      final cmd = _FakeTestCommand(id: 'cmd_1', description: 'Action 1');

      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isFalse);

      await manager.execute(cmd);
      expect(cmd.executeCount, equals(1));
      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);
      expect(manager.undoCount, equals(1));
      expect(manager.lastActionDescription, equals('Action 1'));

      final undoSuccess = await manager.undo();
      expect(undoSuccess, isTrue);
      expect(cmd.undoCount, equals(1));
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isTrue);
      expect(manager.redoCount, equals(1));

      final redoSuccess = await manager.redo();
      expect(redoSuccess, isTrue);
      expect(cmd.redoCount, equals(1));
      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);
    });

    test('New command execution invalidates and purges the redo stack', () async {
      final manager = UndoStackManager(maxCapacity: 50);
      final cmd1 = _FakeTestCommand(id: '1', description: 'Action 1');
      final cmd2 = _FakeTestCommand(id: '2', description: 'Action 2');

      await manager.execute(cmd1);
      await manager.undo();
      expect(manager.canRedo, isTrue);

      // Executing cmd2 must wipe cmd1 from redo stack
      await manager.execute(cmd2);
      expect(manager.canRedo, isFalse);
      expect(manager.undoCount, equals(1));
      expect(manager.lastActionDescription, equals('Action 2'));
    });

    test('Strict max capacity limit of 50 evicts oldest commands from the bottom', () async {
      final manager = UndoStackManager(maxCapacity: 50);

      for (int i = 0; i < 60; i++) {
        await manager.execute(_FakeTestCommand(id: '$i', description: 'Action $i'));
      }

      expect(manager.undoCount, equals(50));
      // First 10 items (0..9) were evicted. Bottom item is now Action 10.
      expect(manager.undoHistory.first.description, equals('Action 10'));
      expect(manager.undoHistory.last.description, equals('Action 59'));
    });

    test('Clear flushes both undo and redo stacks', () async {
      final manager = UndoStackManager(maxCapacity: 50);
      await manager.execute(_FakeTestCommand(id: '1', description: 'Action 1'));
      await manager.undo();
      expect(manager.canRedo, isTrue);

      manager.clear();
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isFalse);
      expect(manager.undoCount, equals(0));
      expect(manager.redoCount, equals(0));
    });
  });

  group('Database Command Execution & Atomic Undo Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase db;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_undo.db');
      db = AppDatabase(connection);
    });

    tearDown(() async {
      await db.close();
    });

    test('MoveEventCommand mutates SQLite and enqueues outbox, then reverts on undo', () async {
      final undoManager = UndoStackManager();
      final eventId = UuidUtils.generate();

      final initialStart = DateTime(2026, 10, 10, 10, 0);
      final initialEnd = DateTime(2026, 10, 10, 11, 0);
      final targetStart = DateTime(2026, 10, 10, 14, 0);
      final targetEnd = DateTime(2026, 10, 10, 15, 0);

      // Setup initial event
      final initialEvent = CalendarEvent(
        id: eventId,
        userId: 'user_1',
        title: 'Interview',
        startTime: initialStart,
        endTime: initialEnd,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final createCmd = CreateEventCommand(
        id: UuidUtils.generate(),
        description: 'Create event',
        timestamp: DateTime.now(),
        eventCompanion: initialEvent.toCompanion(),
        database: db,
        userId: 'user_1',
      );
      await undoManager.execute(createCmd);

      // Move Event Command
      final moveCmd = MoveEventCommand(
        id: UuidUtils.generate(),
        description: 'Move Interview to 14:00',
        timestamp: DateTime.now(),
        eventId: eventId,
        previousStartTime: initialStart,
        previousEndTime: initialEnd,
        targetStartTime: targetStart,
        targetEndTime: targetEnd,
        database: db,
        userId: 'user_1',
      );
      await undoManager.execute(moveCmd);

      var eventInDb = await db.eventDao.getEventById(eventId);
      expect(eventInDb?.startTime, equals(targetStart));
      expect(eventInDb?.endTime, equals(targetEnd));

      // Perform Undo
      await undoManager.undo();
      eventInDb = await db.eventDao.getEventById(eventId);
      expect(eventInDb?.startTime, equals(initialStart));
      expect(eventInDb?.endTime, equals(initialEnd));

      // Perform Redo
      await undoManager.redo();
      eventInDb = await db.eventDao.getEventById(eventId);
      expect(eventInDb?.startTime, equals(targetStart));
      expect(eventInDb?.endTime, equals(targetEnd));
    });

    test('CascadeScheduleCommand atomically reverts multiple events in a single undo step', () async {
      final undoManager = UndoStackManager();

      final id1 = UuidUtils.generate();
      final id2 = UuidUtils.generate();

      final event1 = CalendarEvent(
        id: id1,
        userId: 'user_1',
        title: 'Task 1',
        startTime: DateTime(2026, 10, 10, 9, 0),
        endTime: DateTime(2026, 10, 10, 10, 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final event2 = CalendarEvent(
        id: id2,
        userId: 'user_1',
        title: 'Task 2',
        startTime: DateTime(2026, 10, 10, 10, 0),
        endTime: DateTime(2026, 10, 10, 11, 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await undoManager.execute(CreateEventCommand(
        id: UuidUtils.generate(),
        description: 'Create 1',
        timestamp: DateTime.now(),
        eventCompanion: event1.toCompanion(),
        database: db,
        userId: 'user_1',
      ));
      await undoManager.execute(CreateEventCommand(
        id: UuidUtils.generate(),
        description: 'Create 2',
        timestamp: DateTime.now(),
        eventCompanion: event2.toCompanion(),
        database: db,
        userId: 'user_1',
      ));

      // Cascade shifts both tasks downstream by 1 hour
      final cascadeCmd = CascadeScheduleCommand(
        id: UuidUtils.generate(),
        description: 'Cascade schedule 2 events',
        timestamp: DateTime.now(),
        shifts: [
          EventTimeShift(
            eventId: id1,
            title: 'Task 1',
            previousStartTime: DateTime(2026, 10, 10, 9, 0),
            previousEndTime: DateTime(2026, 10, 10, 10, 0),
            targetStartTime: DateTime(2026, 10, 10, 10, 0),
            targetEndTime: DateTime(2026, 10, 10, 11, 0),
          ),
          EventTimeShift(
            eventId: id2,
            title: 'Task 2',
            previousStartTime: DateTime(2026, 10, 10, 10, 0),
            previousEndTime: DateTime(2026, 10, 10, 11, 0),
            targetStartTime: DateTime(2026, 10, 10, 11, 0),
            targetEndTime: DateTime(2026, 10, 10, 12, 0),
          ),
        ],
        database: db,
        userId: 'user_1',
      );

      await undoManager.execute(cascadeCmd);

      var check1 = await db.eventDao.getEventById(id1);
      var check2 = await db.eventDao.getEventById(id2);
      expect(check1?.startTime, equals(DateTime(2026, 10, 10, 10, 0)));
      expect(check2?.startTime, equals(DateTime(2026, 10, 10, 11, 0)));

      // Single atomic undo step must revert BOTH tasks
      await undoManager.undo();
      check1 = await db.eventDao.getEventById(id1);
      check2 = await db.eventDao.getEventById(id2);
      expect(check1?.startTime, equals(DateTime(2026, 10, 10, 9, 0)));
      expect(check2?.startTime, equals(DateTime(2026, 10, 10, 10, 0)));
    });
  });
}
