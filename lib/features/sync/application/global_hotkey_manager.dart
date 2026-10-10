import 'dart:async';
import 'package:flutter/foundation.dart';

abstract class GlobalHotkeyService {
  Future<bool> registerHotkey({
    required String keyCombination,
    required VoidCallback onTrigger,
  });

  Future<void> unregisterHotkey(String keyCombination);

  Future<void> unregisterAll();

  bool isRegistered(String keyCombination);
}

class MockGlobalHotkeyService implements GlobalHotkeyService {
  final Map<String, VoidCallback> _callbacks = {};

  @override
  Future<bool> registerHotkey({
    required String keyCombination,
    required VoidCallback onTrigger,
  }) async {
    _callbacks[keyCombination] = onTrigger;
    return true;
  }

  @override
  Future<void> unregisterHotkey(String keyCombination) async {
    _callbacks.remove(keyCombination);
  }

  @override
  Future<void> unregisterAll() async {
    _callbacks.clear();
  }

  @override
  bool isRegistered(String keyCombination) =>
      _callbacks.containsKey(keyCombination);

  /// Simulate pressing the global hotkey in tests
  void simulateHotkeyPress(String keyCombination) {
    final cb = _callbacks[keyCombination];
    if (cb != null) {
      cb();
    }
  }
}

class GlobalHotkeyManager {
  final GlobalHotkeyService _hotkeyService;
  static const String defaultQuickCaptureHotkey = 'Meta+Shift+C'; // Win+Shift+C on Windows

  bool _isEnabled = true;
  VoidCallback? _quickCaptureCallback;

  GlobalHotkeyManager({required GlobalHotkeyService hotkeyService})
      : _hotkeyService = hotkeyService;

  bool get isEnabled => _isEnabled;

  Future<bool> registerQuickCapture({
    required VoidCallback onTrigger,
    String hotkey = defaultQuickCaptureHotkey,
  }) async {
    _quickCaptureCallback = onTrigger;
    return await _hotkeyService.registerHotkey(
      keyCombination: hotkey,
      onTrigger: () {
        if (_isEnabled && _quickCaptureCallback != null) {
          _quickCaptureCallback!();
        }
      },
    );
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
  }

  Future<void> dispose() async {
    await _hotkeyService.unregisterAll();
    _quickCaptureCallback = null;
  }
}
