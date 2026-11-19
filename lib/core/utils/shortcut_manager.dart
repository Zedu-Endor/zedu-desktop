import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifier for a keyboard shortcut, built from its logical key name and
/// active modifier keys (e.g. `"ctrl+s"`).
String shortcutKey(LogicalKeyboardKey key, Set<String> modifiers) {
  final sorted = modifiers.toList()..sort();
  return '${sorted.join('+')}+${key.keyLabel}'.toLowerCase();
}

/// Builds the modifier set currently held on the keyboard.
Set<String> currentModifiers() {
  final mods = <String>{};
  if (HardwareKeyboard.instance.isControlPressed) mods.add('ctrl');
  if (HardwareKeyboard.instance.isShiftPressed) mods.add('shift');
  if (HardwareKeyboard.instance.isAltPressed) mods.add('alt');
  if (HardwareKeyboard.instance.isMetaPressed) mods.add('meta');
  return mods;
}

/// Manages which keyboard shortcuts the application handles itself versus
/// passing through to the operating system.
///
/// Shortcuts that collide with Windows/macOS system shortcuts (for example
/// `Ctrl+S` save, `Ctrl+P` print) default to disabled so they are not
/// intercepted by the app.
class ShortcutManager extends Notifier<Map<String, bool>> {
  /// Shortcuts that collide with OS-level commands and should be passed
  /// through to the system by default.
  static const List<String> _systemReserved = <String>[
    'ctrl+s',
    'ctrl+p',
    'meta+s',
    'meta+p',
  ];

  @override
  Map<String, bool> build() {
    final enabled = <String, bool>{};
    for (final reserved in _systemReserved) {
      enabled[reserved] = false;
    }
    return enabled;
  }

  /// Whether [keyId] should be handled by the app. Returns `false` for
  /// system-reserved shortcuts unless they have been explicitly re-enabled.
  bool isEnabled(String keyId) => state[keyId] ?? true;

  /// Enable or disable a shortcut. Disabled shortcuts are passed through to
  /// the operating system.
  void setEnabled(String keyId, bool enabled) {
    state = Map<String, bool>.from(state)..[keyId] = enabled;
  }

  /// Returns `true` when the shortcut should be passed through to the OS
  /// instead of being handled by the app.
  bool shouldPassToSystem(LogicalKeyboardKey key, Set<String> modifiers) {
    return !isEnabled(shortcutKey(key, modifiers));
  }
}

final shortcutManagerProvider =
    NotifierProvider<ShortcutManager, Map<String, bool>>(ShortcutManager.new);
