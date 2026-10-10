import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../domain/entities/keep_item.dart';
import '../../domain/repositories/keep_repository.dart';
import '../../data/repositories/keep_repository_impl.dart';

final keepRepositoryProvider = Provider<KeepRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return KeepRepositoryImpl(database: db);
});

final activeKeepItemsStreamProvider =
    StreamProvider.family<List<KeepItem>, String>((ref, userId) {
  final repo = ref.watch(keepRepositoryProvider);
  return repo.watchActiveKeepItems(userId);
});

final archivedKeepItemsStreamProvider =
    StreamProvider.family<List<KeepItem>, String>((ref, userId) {
  final repo = ref.watch(keepRepositoryProvider);
  return repo.watchArchivedKeepItems(userId);
});

/// Controls whether the Keep Pool sidebar or sheet is visible.
final isKeepPoolOpenProvider = StateProvider<bool>((ref) => false);
