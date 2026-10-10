import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/undo/undo_stack_providers.dart';
import '../widgets/command_palette_modal.dart';
import 'calendar_intents.dart';

class CalendarShortcutsWrapper extends ConsumerWidget {
  final Widget child;

  const CalendarShortcutsWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final undoManager = ref.watch(undoStackManagerProvider);

    final shortcuts = <ShortcutActivator, Intent>{
      // Ctrl+Z (Windows/Linux/Web) / Cmd+Z (macOS)
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): const CalendarUndoIntent(),
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): const CalendarUndoIntent(),

      // Redo: Ctrl+Y / Cmd+Shift+Z / Ctrl+Shift+Z
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): const CalendarRedoIntent(),
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): const CalendarRedoIntent(),
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): const CalendarRedoIntent(),

      // Command Palette: Ctrl+K / Cmd+K
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): const CalendarCommandPaletteIntent(),
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): const CalendarCommandPaletteIntent(),
    };

    final actions = <Type, Action<Intent>>{
      CalendarUndoIntent: CallbackAction<CalendarUndoIntent>(
        onInvoke: (intent) {
          // Guard: Text editing fields retain their native Ctrl+Z
          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null &&
              primaryFocus.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
            return null;
          }
          if (undoManager.canUndo) {
            final desc = undoManager.lastActionDescription;
            undoManager.undo();
            if (desc != null && context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已復原：$desc'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  action: undoManager.canRedo
                      ? SnackBarAction(
                          label: '重做',
                          onPressed: () => undoManager.redo(),
                        )
                      : null,
                ),
              );
            }
          }
          return null;
        },
      ),
      CalendarRedoIntent: CallbackAction<CalendarRedoIntent>(
        onInvoke: (intent) {
          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null &&
              primaryFocus.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
            return null;
          }
          if (undoManager.canRedo) {
            final desc = undoManager.nextRedoDescription;
            undoManager.redo();
            if (desc != null && context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已重做：$desc'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  action: undoManager.canUndo
                      ? SnackBarAction(
                          label: '復原',
                          onPressed: () => undoManager.undo(),
                        )
                      : null,
                ),
              );
            }
          }
          return null;
        },
      ),
      CalendarCommandPaletteIntent: CallbackAction<CalendarCommandPaletteIntent>(
        onInvoke: (intent) {
          showCommandPaletteModal(context);
          return null;
        },
      ),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: actions,
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
