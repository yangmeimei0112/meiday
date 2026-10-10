import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../application/global_hotkey_manager.dart';
import '../../application/widget_snapshot_exporter.dart';
import '../../domain/entities/today_widget_snapshot.dart';

final globalHotkeyServiceProvider = Provider<GlobalHotkeyService>((ref) {
  return MockGlobalHotkeyService();
});

final globalHotkeyManagerProvider = Provider<GlobalHotkeyManager>((ref) {
  final service = ref.watch(globalHotkeyServiceProvider);
  final manager = GlobalHotkeyManager(hotkeyService: service);
  ref.onDispose(() {
    manager.dispose();
  });
  return manager;
});

final widgetSnapshotExporterProvider = Provider<WidgetSnapshotExporter>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final widgetService = ref.watch(widgetSyncServiceProvider);
  return WidgetSnapshotExporter(
    db: db,
    widgetService: widgetService,
  );
});

final todayWidgetSnapshotFutureProvider =
    FutureProvider<TodayWidgetSnapshot>((ref) async {
  final exporter = ref.watch(widgetSnapshotExporterProvider);
  return await exporter.exportSnapshot();
});
