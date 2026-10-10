import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../calendar/domain/entities/schedule_models.dart';
import '../../domain/entities/calendar_space.dart';
import '../../domain/repositories/linked_mirroring_repository.dart';
import '../../domain/repositories/space_repository.dart';
import '../../data/repositories/linked_mirroring_repository_impl.dart';
import '../../data/repositories/space_repository_impl.dart';

final spaceRepositoryProvider = Provider<SpaceRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SpaceRepositoryImpl(database: db);
});

final linkedMirroringRepositoryProvider = Provider<LinkedMirroringRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LinkedMirroringRepositoryImpl(database: db);
});

final spacesStreamProvider = StreamProvider<List<CalendarSpace>>((ref) {
  final repo = ref.watch(spaceRepositoryProvider);
  return repo.watchAllSpaces();
});

/// StateNotifier tracking active space IDs visible on the calendar canvas.
class ActiveSpacesNotifier extends StateNotifier<Set<String>> {
  ActiveSpacesNotifier() : super({});

  void initialize(List<CalendarSpace> spaces) {
    if (state.isEmpty && spaces.isNotEmpty) {
      state = spaces.map((s) => s.id).toSet();
    }
  }

  void toggleSpace(String spaceId) {
    final next = Set<String>.from(state);
    if (next.contains(spaceId)) {
      next.remove(spaceId);
    } else {
      next.add(spaceId);
    }
    state = next;
  }

  void selectAll(List<CalendarSpace> spaces) {
    state = spaces.map((s) => s.id).toSet();
  }

  void clearAll() {
    state = {};
  }

  void isolateSpace(String spaceId) {
    state = {spaceId};
  }
}

final activeSpaceIdsProvider = StateNotifierProvider<ActiveSpacesNotifier, Set<String>>((ref) {
  final notifier = ActiveSpacesNotifier();
  ref.listen<AsyncValue<List<CalendarSpace>>>(spacesStreamProvider, (prev, next) {
    next.whenData((spaces) => notifier.initialize(spaces));
  });
  return notifier;
});

/// Reactive map of eventId -> List<CalendarSpace>
final eventLinkedSpacesMapProvider = StreamProvider<Map<String, List<CalendarSpace>>>((ref) {
  final repo = ref.watch(linkedMirroringRepositoryProvider);
  return repo.watchEventToSpacesMap();
});

/// Reactive stream of events filtered by active spaces.
/// If active spaces are empty or not initialized yet, falls back to all events or empty set.
final filteredCalendarEventsStreamProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final activeIds = ref.watch(activeSpaceIdsProvider);
  final repo = ref.watch(linkedMirroringRepositoryProvider);

  if (activeIds.isEmpty) {
    // If no space is active, show empty
    return Stream.value(<CalendarEvent>[]);
  }

  return repo.watchEventsForSpaces(activeIds.toList());
});
