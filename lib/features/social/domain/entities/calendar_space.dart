import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';

@immutable
class CalendarSpace {
  final String id;
  final String userId;
  final String name;
  final String type; // 'personal', 'couple', 'family', 'project'
  final int color; // 32-bit ARGB
  final String? icon; // Emoji icon string (e.g. '👤', '❤️', '🏠', '💼')
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const CalendarSpace({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.color,
    this.icon,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Color get colorValue => Color(color);

  CalendarSpace copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    int? color,
    String? icon,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return CalendarSpace(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  factory CalendarSpace.fromData(CalendarSpaceData data) {
    return CalendarSpace(
      id: data.id,
      userId: data.userId,
      name: data.name,
      type: data.type,
      color: data.color,
      icon: data.icon,
      isDefault: data.isDefault,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      isDeleted: data.isDeleted,
    );
  }

  CalendarSpacesCompanion toCompanion() {
    return CalendarSpacesCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      type: Value(type),
      color: Value(color),
      icon: Value(icon),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'type': type,
    'color': color,
    'icon': icon,
    'is_default': isDefault,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_deleted': isDeleted,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarSpace && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
