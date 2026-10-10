import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../domain/entities/calendar_space.dart';
import '../../domain/repositories/space_repository.dart';

class SpaceRepositoryImpl implements SpaceRepository {
  final AppDatabase database;

  SpaceRepositoryImpl({required this.database});

  @override
  Stream<List<CalendarSpace>> watchAllSpaces() {
    return database.spaceDao.watchAllSpaces().map(
          (rows) => rows.map(CalendarSpace.fromData).toList(),
        );
  }

  @override
  Future<List<CalendarSpace>> getAllSpaces() async {
    final rows = await (database.select(database.calendarSpaces)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    return rows.map(CalendarSpace.fromData).toList();
  }

  @override
  Future<CalendarSpace?> getDefaultSpace() async {
    final row = await database.spaceDao.getDefaultSpace();
    if (row == null) return null;
    return CalendarSpace.fromData(row);
  }

  @override
  Future<CalendarSpace?> getSpaceById(String id) async {
    final row = await (database.select(database.calendarSpaces)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    if (row == null) return null;
    return CalendarSpace.fromData(row);
  }

  @override
  Future<void> ensureDefaultSpacesSeeded({required String userId}) async {
    final existing = await getAllSpaces();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final defaultDefs = [
      (
        id: UuidUtils.generate(),
        name: '個人',
        type: 'personal',
        color: AppColors.spacePersonal.toARGB32(),
        icon: '👤',
        isDefault: true,
      ),
      (
        id: UuidUtils.generate(),
        name: '伴侶',
        type: 'couple',
        color: AppColors.spacePartner.toARGB32(),
        icon: '❤️',
        isDefault: false,
      ),
      (
        id: UuidUtils.generate(),
        name: '家庭',
        type: 'family',
        color: AppColors.spaceFamily.toARGB32(),
        icon: '🏠',
        isDefault: false,
      ),
      (
        id: UuidUtils.generate(),
        name: '工作',
        type: 'project',
        color: AppColors.spaceWork.toARGB32(),
        icon: '💼',
        isDefault: false,
      ),
    ];

    await database.transaction(() async {
      for (final def in defaultDefs) {
        final space = CalendarSpace(
          id: def.id,
          userId: userId,
          name: def.name,
          type: def.type,
          color: def.color,
          icon: def.icon,
          isDefault: def.isDefault,
          createdAt: now,
          updatedAt: now,
        );

        await database.spaceDao.insertSpace(space.toCompanion());

        await database.outboxDao.enqueueMutation(
          id: UuidUtils.generate(),
          tableName: DbConstants.tableSpaces,
          recordId: def.id,
          action: DbConstants.outboxActionInsert,
          payloadJson: jsonEncode(space.toJson()),
        );
      }
    });
  }

  @override
  Future<CalendarSpace> createSpace({
    required String name,
    required String type,
    required int color,
    String? icon,
    bool isDefault = false,
    required String userId,
  }) async {
    final id = UuidUtils.generate();
    final now = DateTime.now();

    final space = CalendarSpace(
      id: id,
      userId: userId,
      name: name,
      type: type,
      color: color,
      icon: icon,
      isDefault: isDefault,
      createdAt: now,
      updatedAt: now,
    );

    await database.transaction(() async {
      await database.spaceDao.insertSpace(space.toCompanion());

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableSpaces,
        recordId: id,
        action: DbConstants.outboxActionInsert,
        payloadJson: jsonEncode(space.toJson()),
      );
    });

    return space;
  }

  @override
  Future<void> updateSpace(CalendarSpace space) async {
    final now = DateTime.now();
    final updated = space.copyWith(updatedAt: now);

    await database.transaction(() async {
      await database.spaceDao.updateSpace(updated.toCompanion());

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableSpaces,
        recordId: space.id,
        action: DbConstants.outboxActionUpdate,
        payloadJson: jsonEncode(updated.toJson()),
      );
    });
  }

  @override
  Future<void> deleteSpace(String spaceId) async {
    final now = DateTime.now();
    await database.transaction(() async {
      await database.spaceDao.softDeleteSpace(spaceId);

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableSpaces,
        recordId: spaceId,
        action: DbConstants.outboxActionDelete,
        payloadJson: jsonEncode({
          'id': spaceId,
          'is_deleted': true,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }
}
