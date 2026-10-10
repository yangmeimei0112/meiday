class DbConstants {
  // Physical DB File Names
  static const String guestDbName = 'guest.db';
  static const String userDbPrefix = 'user_';
  static const String userDbSuffix = '.db';

  // SQLite Tables
  static const String tableUserProfile = 'local_user_profile';
  static const String tableSpaces = 'calendar_spaces';
  static const String tableEvents = 'calendar_events';
  static const String tableEventSpaceLinks = 'event_space_links';
  static const String tableEventComments = 'event_comments';
  static const String tableEventChecklists = 'event_checklists';
  static const String tableEventAttachments = 'event_attachments';
  static const String tablePomodoroSessions = 'pomodoro_sessions';
  static const String tableSyncOutbox = 'sync_outbox';
  static const String tableUserDevices = 'user_devices';
  static const String tableKeepItems = 'keep_items';

  // Outbox Status
  static const String outboxStatusPending = 'pending';
  static const String outboxStatusProcessing = 'processing';
  static const String outboxStatusSynced = 'synced';
  static const String outboxStatusFailed = 'failed';

  // Outbox Actions
  static const String outboxActionInsert = 'INSERT';
  static const String outboxActionUpdate = 'UPDATE';
  static const String outboxActionDelete = 'DELETE';

  // Event Status
  static const String eventStatusPending = 'pending';
  static const String eventStatusInProgress = 'in_progress';
  static const String eventStatusCompleted = 'completed';
  static const String eventStatusCancelled = 'cancelled';
}
