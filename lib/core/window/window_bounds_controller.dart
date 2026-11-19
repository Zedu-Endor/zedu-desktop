import 'dart:async';
import 'dart:convert';

import 'package:screen_retriever/screen_retriever.dart' show screenRetriever;
import 'package:zedu/core/core.dart';

/// The size below which the sidebar, message list and composer stop fitting.
const kMinimumWindowSize = Size(960, 600);

const _boundsKeyPrefix = 'window_bounds.';
const _lastDisplayKey = 'window_bounds.last_display';

/// The key bounds were saved under before they were kept per display.
const _legacyBoundsKey = 'window_bounds';

/// A display's identity and the area a window may occupy on it.
class WindowDisplay {
  const WindowDisplay({required this.id, required this.area});

  final String id;
  final Rect area;
}

class SavedWindowBounds {
  const SavedWindowBounds({
    required this.rect,
    required this.isMaximized,
    this.displayId,
  });

  final Rect rect;
  final bool isMaximized;

  /// The display the window was last used on. Null in values saved before
  /// bounds were kept per display.
  final String? displayId;

  String toJson() => jsonEncode({
    'x': rect.left,
    'y': rect.top,
    'width': rect.width,
    'height': rect.height,
    'maximized': isMaximized,
    if (displayId != null) 'displayId': displayId,
  });

  /// Returns null for anything that is not a complete saved value.
  static SavedWindowBounds? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final displayId = json['displayId'];
      return SavedWindowBounds(
        rect: Rect.fromLTWH(
          (json['x'] as num).toDouble(),
          (json['y'] as num).toDouble(),
          (json['width'] as num).toDouble(),
          (json['height'] as num).toDouble(),
        ),
        isMaximized: json['maximized'] as bool? ?? false,
        displayId: displayId is String && displayId.isNotEmpty
            ? displayId
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Fits [bounds] onto [display]: the size is kept whenever it fits and is
/// shrunk only when the window is larger than the display.
Rect clampBoundsToDisplay(Rect bounds, Rect display) {
  final minWidth = display.width < kMinimumWindowSize.width
      ? display.width
      : kMinimumWindowSize.width;
  final minHeight = display.height < kMinimumWindowSize.height
      ? display.height
      : kMinimumWindowSize.height;
  final width = bounds.width.clamp(minWidth, display.width).toDouble();
  final height = bounds.height.clamp(minHeight, display.height).toDouble();
  final left = bounds.left
      .clamp(display.left, display.right - width)
      .toDouble();
  final top = bounds.top.clamp(display.top, display.bottom - height).toDouble();
  return Rect.fromLTWH(left, top, width, height);
}

Future<List<WindowDisplay>> _readDisplays() async {
  final displays = await screenRetriever.getAllDisplays();
  return [
    for (final display in displays)
      WindowDisplay(
        id: display.id,
        area:
            (display.visiblePosition ?? Offset.zero) &
            (display.visibleSize ?? display.size),
      ),
  ];
}

/// Enforces the minimum window size and remembers where the window was left,
/// per display, so it reopens on the monitor it was last used on.
class WindowBoundsController with WindowListener {
  WindowBoundsController({
    required WindowManager window,
    required SecureStorageService storage,
    Future<List<WindowDisplay>> Function() displays = _readDisplays,
    Duration saveDelay = const Duration(milliseconds: 500),
  }) : _window = window,
       _storage = storage,
       _displays = displays,
       _saveDelay = saveDelay;

  final WindowManager _window;
  final SecureStorageService _storage;
  final Future<List<WindowDisplay>> Function() _displays;
  final Duration _saveDelay;

  Timer? _saveTimer;

  /// The last size and position outside the maximized state, so unmaximizing
  /// after a restart returns to it.
  Rect? _normalBounds;

  /// Runs before the first frame. A failure here must never stop the app
  /// from starting, so it falls back to the default window.
  Future<void> restore() async {
    try {
      await _window.setMinimumSize(kMinimumWindowSize);
      final displays = await _displays();
      final saved = await _readSavedBounds();
      final display = saved == null ? null : _displayForSaved(saved, displays);
      if (saved != null && display != null) {
        final bounds = clampBoundsToDisplay(saved.rect, display.area);
        _normalBounds = bounds;
        await _window.setBounds(bounds);
        if (saved.isMaximized) await _window.maximize();
      }
    } catch (error) {
      debugPrint('Failed to restore window bounds: $error');
    }
    _window.addListener(this);
  }

  /// Reads the bounds kept for the display used last, falling back to the one
  /// value saved before bounds were kept per display.
  Future<SavedWindowBounds?> _readSavedBounds() async {
    final lastDisplay = await _storage.readData(_lastDisplayKey);
    if (lastDisplay != null && lastDisplay.isNotEmpty) {
      final saved = SavedWindowBounds.tryParse(
        await _storage.readData('$_boundsKeyPrefix$lastDisplay'),
      );
      if (saved != null) return saved;
    }
    return SavedWindowBounds.tryParse(
      await _storage.readData(_legacyBoundsKey),
    );
  }

  static WindowDisplay? _displayForSaved(
    SavedWindowBounds saved,
    List<WindowDisplay> displays,
  ) {
    for (final display in displays) {
      if (display.id == saved.displayId) return display;
    }
    // A per-display value whose display is gone falls back to the default
    // window; only an old single value is placed by where it was.
    if (saved.displayId != null) return null;
    return _displayForBounds(saved.rect, displays);
  }

  static WindowDisplay? _displayForBounds(
    Rect bounds,
    List<WindowDisplay> displays,
  ) {
    WindowDisplay? best;
    var bestArea = 0.0;
    for (final display in displays) {
      final overlap = bounds.intersect(display.area);
      final area = overlap.width > 0 && overlap.height > 0
          ? overlap.width * overlap.height
          : 0.0;
      if (best == null || area > bestArea) {
        best = display;
        bestArea = area;
      }
    }
    return bestArea > 0 ? best : null;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _save);
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    try {
      // A minimized window reports a position far off-screen on Windows.
      if (await _window.isMinimized()) return;
      final isMaximized = await _window.isMaximized();
      final bounds = await _window.getBounds();
      if (!isMaximized) _normalBounds = bounds;
      final rect = _normalBounds ?? bounds;
      final display = _displayForBounds(rect, await _displays());
      if (display == null) return;
      await _storage.writeData(
        '$_boundsKeyPrefix${display.id}',
        SavedWindowBounds(
          rect: rect,
          isMaximized: isMaximized,
          displayId: display.id,
        ).toJson(),
      );
      await _storage.writeData(_lastDisplayKey, display.id);
    } catch (error) {
      debugPrint('Failed to save window bounds: $error');
    }
  }

  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowMove() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  @override
  void onWindowClose() => unawaited(_save());
}
