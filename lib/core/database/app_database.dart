import 'package:drift/drift.dart';
import 'tables/calendar_spaces_table.dart';
import 'tables/calendar_events_table.dart';
import 'tables/event_space_links_table.dart';
import 'tables/event_comments_table.dart';
import 'tables/event_attachments_table.dart';
import 'tables/event_checklists_table.dart';
import 'tables/keep_items_table.dart';
import 'tables/user_devices_table.dart';
import 'tables/sync_outbox_table.dart';
import 'tables/pomodoro_sessions_table.dart';

import 'daos/event_dao.dart';
import 'daos/space_dao.dart';
import 'daos/event_space_link_dao.dart';
import 'daos/checklist_dao.dart';
import 'daos/comment_dao.dart';
import 'daos/keep_item_dao.dart';
import 'daos/user_device_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/pomodoro_session_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    CalendarSpaces,
    CalendarEvents,
    EventSpaceLinks,
    EventComments,
    EventAttachments,
    EventChecklists,
    KeepItems,
    UserDevices,
    SyncOutbox,
    PomodoroSessions,
  ],
  daos: [
    EventDao,
    SpaceDao,
    EventSpaceLinkDao,
    ChecklistDao,
    CommentDao,
    KeepItemDao,
    UserDeviceDao,
    OutboxDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  late final PomodoroSessionDao pomodoroSessionDao = PomodoroSessionDao(this);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }
}
