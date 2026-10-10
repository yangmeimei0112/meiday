import '../entities/keep_item.dart';

abstract class KeepRepository {
  /// Stream of active (unscheduled, unarchived) keep items.
  Stream<List<KeepItem>> watchActiveKeepItems(String userId);

  /// Stream of archived keep items.
  Stream<List<KeepItem>> watchArchivedKeepItems(String userId);

  /// Get active keep items once.
  Future<List<KeepItem>> getActiveKeepItems(String userId);

  /// Get single keep item by ID.
  Future<KeepItem?> getKeepItemById(String id);

  /// Create a new keep inspiration item.
  Future<KeepItem> createKeepItem(KeepItem item);

  /// Update an existing keep item.
  Future<void> updateKeepItem(KeepItem item);

  /// Archive a keep item.
  Future<void> archiveKeepItem(String id);

  /// Unarchive a keep item (e.g. on Undo).
  Future<void> unarchiveKeepItem(String id);

  /// Soft-delete a keep item.
  Future<void> deleteKeepItem(String id);
}
