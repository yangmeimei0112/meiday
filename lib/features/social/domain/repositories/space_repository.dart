import '../entities/calendar_space.dart';

abstract class SpaceRepository {
  /// Stream of all active (non-deleted) spaces.
  Stream<List<CalendarSpace>> watchAllSpaces();

  /// Retrieve all active spaces once.
  Future<List<CalendarSpace>> getAllSpaces();

  /// Retrieve default space for user.
  Future<CalendarSpace?> getDefaultSpace();

  /// Retrieve space by id.
  Future<CalendarSpace?> getSpaceById(String id);

  /// Ensure the 4 default spaces (Personal, Partner, Family, Work) are seeded.
  Future<void> ensureDefaultSpacesSeeded({required String userId});

  /// Create a new space and enqueue outbox insert.
  Future<CalendarSpace> createSpace({
    required String name,
    required String type,
    required int color,
    String? icon,
    bool isDefault = false,
    required String userId,
  });

  /// Update an existing space and enqueue outbox update.
  Future<void> updateSpace(CalendarSpace space);

  /// Soft-delete a space and enqueue outbox delete.
  Future<void> deleteSpace(String spaceId);
}
