import 'package:flutter/foundation.dart';
import '../commands/calendar_command.dart';

class UndoStackManager extends ChangeNotifier {
  final int maxCapacity;
  final List<CalendarCommand> _undoStack = [];
  final List<CalendarCommand> _redoStack = [];
  bool _isExecuting = false;

  UndoStackManager({this.maxCapacity = 50});

  bool get canUndo => _undoStack.isNotEmpty && !_isExecuting;
  bool get canRedo => _redoStack.isNotEmpty && !_isExecuting;
  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;
  bool get isExecuting => _isExecuting;

  String? get lastActionDescription => _undoStack.isNotEmpty ? _undoStack.last.description : null;
  String? get nextRedoDescription => _redoStack.isNotEmpty ? _redoStack.last.description : null;

  List<CalendarCommand> get undoHistory => List.unmodifiable(_undoStack);
  List<CalendarCommand> get redoHistory => List.unmodifiable(_redoStack);

  /// Executes a command and registers it onto the undo stack.
  Future<void> execute(CalendarCommand command) async {
    if (_isExecuting) return;
    _isExecuting = true;
    notifyListeners();

    try {
      await command.execute();
      _undoStack.add(command);
      while (_undoStack.length > maxCapacity) {
        _undoStack.removeAt(0); // Evict oldest
      }
      _redoStack.clear(); // Invalidate redo branch
    } finally {
      _isExecuting = false;
      notifyListeners();
    }
  }

  /// Undoes the topmost command.
  Future<bool> undo() async {
    if (!canUndo) return false;
    _isExecuting = true;
    notifyListeners();

    final command = _undoStack.removeLast();
    try {
      await command.undo();
      _redoStack.add(command);
      return true;
    } catch (e) {
      _undoStack.add(command); // Restore stack integrity
      rethrow;
    } finally {
      _isExecuting = false;
      notifyListeners();
    }
  }

  /// Redoes the topmost command.
  Future<bool> redo() async {
    if (!canRedo) return false;
    _isExecuting = true;
    notifyListeners();

    final command = _redoStack.removeLast();
    try {
      await command.redo();
      _undoStack.add(command);
      while (_undoStack.length > maxCapacity) {
        _undoStack.removeAt(0);
      }
      return true;
    } catch (e) {
      _redoStack.add(command); // Restore stack integrity
      rethrow;
    } finally {
      _isExecuting = false;
      notifyListeners();
    }
  }

  /// Clears all undo/redo history.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}
