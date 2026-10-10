import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';
import 'grocery_category.dart';

@immutable
class EventChecklistItem {
  final String id;
  final String eventId;
  final String title;
  final bool isCompleted;
  final String? assignedToUserId;
  final int sortOrder;
  final GroceryCategory groceryCategory;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const EventChecklistItem({
    required this.id,
    required this.eventId,
    required this.title,
    required this.isCompleted,
    this.assignedToUserId,
    required this.sortOrder,
    this.groceryCategory = GroceryCategory.other,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  EventChecklistItem copyWith({
    String? id,
    String? eventId,
    String? title,
    bool? isCompleted,
    String? assignedToUserId,
    int? sortOrder,
    GroceryCategory? groceryCategory,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return EventChecklistItem(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      sortOrder: sortOrder ?? this.sortOrder,
      groceryCategory: groceryCategory ?? this.groceryCategory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  static final RegExp _tagRegex = RegExp(r'^\[([^\]]+)\]\s*(.*)$');

  factory EventChecklistItem.fromData(EventChecklistData data) {
    final rawTitle = data.title;
    final match = _tagRegex.firstMatch(rawTitle);

    if (match != null) {
      final categoryStr = match.group(1);
      final cleanTitle = match.group(2) ?? '';
      return EventChecklistItem(
        id: data.id,
        eventId: data.eventId,
        title: cleanTitle,
        isCompleted: data.isCompleted,
        assignedToUserId: data.assignedToUserId,
        sortOrder: data.sortOrder,
        groceryCategory: GroceryCategory.fromName(categoryStr),
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
        isDeleted: data.isDeleted,
      );
    } else {
      final detected = GroceryCategoryClassifier.classify(rawTitle);
      return EventChecklistItem(
        id: data.id,
        eventId: data.eventId,
        title: rawTitle,
        isCompleted: data.isCompleted,
        assignedToUserId: data.assignedToUserId,
        sortOrder: data.sortOrder,
        groceryCategory: detected,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
        isDeleted: data.isDeleted,
      );
    }
  }

  String get persistedTitle {
    if (groceryCategory != GroceryCategory.other) {
      return '[${groceryCategory.name}] $title';
    }
    return title;
  }

  EventChecklistsCompanion toCompanion({bool encodeCategory = true}) {
    final effectiveTitle = encodeCategory ? persistedTitle : title;
    return EventChecklistsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      title: Value(effectiveTitle),
      isCompleted: Value(isCompleted),
      assignedToUserId: Value(assignedToUserId),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'event_id': eventId,
    'title': persistedTitle,
    'is_completed': isCompleted,
    'assigned_to_user_id': assignedToUserId,
    'sort_order': sortOrder,
    'category': groceryCategory.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_deleted': isDeleted,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventChecklistItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
