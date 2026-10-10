import '../../../calendar/domain/entities/schedule_models.dart';
import '../entities/calendar_space.dart';

abstract class LinkedMirroringRepository {
  /// Watch calendar events filtered by active space IDs (deduplicated via DISTINCT).
  Stream<List<CalendarEvent>> watchEventsForSpaces(List<String> spaceIds);

  /// Watch space IDs linked to an event.
  Stream<List<String>> watchSpaceIdsForEvent(String eventId);

  /// Get space IDs linked to an event once.
  Future<List<String>> getSpaceIdsForEvent(String eventId);

  /// Watch reactive mapping of eventId -> List<CalendarSpace> for canvas rendering.
  Stream<Map<String, List<CalendarSpace>>> watchEventToSpacesMap();

  /// Link an event to multiple spaces without data duplication (atomic + outbox).
  Future<void> linkEventToSpaces({
    required String eventId,
    required List<String> spaceIds,
    required String userId,
  });

  /// Reconcile differential links (insert newly selected, delete unselected).
  Future<void> updateEventSpaceLinks({
    required String eventId,
    required List<String> targetSpaceIds,
    required String userId,
  });

  /// Remove link between an event and a space.
  Future<void> unlinkEventFromSpace({
    required String eventId,
    required String spaceId,
    required String userId,
  });
}
