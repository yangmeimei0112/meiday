import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database_provider.dart';
import 'undo_stack_manager.dart';

final undoStackManagerProvider = ChangeNotifierProvider<UndoStackManager>((ref) {
  final manager = UndoStackManager(maxCapacity: 50);

  // Sever undo stack across auth / physical DB switches
  ref.listen(currentAuthForDbProvider, (prev, next) {
    manager.clear();
  });

  return manager;
});
