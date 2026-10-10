import '../entities/event_checklist_item.dart';
import '../entities/grocery_category.dart';

abstract class ChecklistRepository {
  /// Reactive stream of checklist items for an event sorted by sortOrder.
  Stream<List<EventChecklistItem>> watchChecklist(String eventId);

  /// Get checklist items for an event once.
  Future<List<EventChecklistItem>> getChecklist(String eventId);

  /// Add a new item with smart or specified grocery category.
  Future<EventChecklistItem> addItem({
    required String eventId,
    required String title,
    String? assignedToUserId,
    GroceryCategory? category,
    required String userId,
  });

  /// Toggle completion status of an item.
  Future<void> toggleItem({
    required String itemId,
    required bool isCompleted,
    required String userId,
  });

  /// Batch update sort order for drag-and-drop reordering.
  Future<void> reorderItems({
    required String eventId,
    required List<String> orderedItemIds,
    required String userId,
  });

  /// Soft-delete an item.
  Future<void> deleteItem({
    required String itemId,
    required String userId,
  });
}
