import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';

class _MockWindowManager extends Mock implements WindowManager {}

class _MockStorage extends Mock implements SecureStorageService {}

class _FakeWindowListener extends Fake implements WindowListener {}

const _primary = WindowDisplay(
  id: 'display-1',
  area: Rect.fromLTWH(0, 0, 1920, 1040),
);
const _secondary = WindowDisplay(
  id: 'display-2',
  area: Rect.fromLTWH(1920, 0, 1920, 1040),
);
const _saved = Rect.fromLTWH(100, 80, 1200, 700);
const _savedOnSecondary = Rect.fromLTWH(2200, 120, 1200, 700);

void main() {
  setUpAll(() {
    registerFallbackValue(Size.zero);
    registerFallbackValue(Rect.zero);
    registerFallbackValue(_FakeWindowListener());
  });

  late _MockWindowManager window;
  late _MockStorage storage;

  WindowBoundsController controller({
    List<WindowDisplay> displays = const [_primary],
  }) {
    return WindowBoundsController(
      window: window,
      storage: storage,
      displays: () async => displays,
      saveDelay: Duration.zero,
    );
  }

  void stubStored(Map<String, String?> values) {
    when(() => storage.readData(any())).thenAnswer(
      (invocation) async => values[invocation.positionalArguments.first],
    );
  }

  String storedBounds({
    Rect rect = _saved,
    bool isMaximized = false,
    String? displayId = 'display-1',
  }) {
    return SavedWindowBounds(
      rect: rect,
      isMaximized: isMaximized,
      displayId: displayId,
    ).toJson();
  }

  setUp(() {
    window = _MockWindowManager();
    storage = _MockStorage();
    when(() => window.setMinimumSize(any())).thenAnswer((_) async {});
    when(() => window.setBounds(any())).thenAnswer((_) async {});
    when(() => window.maximize()).thenAnswer((_) async {});
    when(() => window.addListener(any())).thenReturn(null);
    when(() => window.isMinimized()).thenAnswer((_) async => false);
    when(() => window.isMaximized()).thenAnswer((_) async => false);
    when(() => window.getBounds()).thenAnswer((_) async => _saved);
    when(() => storage.writeData(any(), any())).thenAnswer((_) async {});
  });

  group('restore', () {
    test('always sets the minimum size', () async {
      stubStored({});

      await controller().restore();

      verify(() => window.setMinimumSize(kMinimumWindowSize)).called(1);
      verifyNever(() => window.setBounds(any()));
    });

    test('applies the bounds saved for the last display used', () async {
      stubStored({
        'window_bounds.last_display': 'display-1',
        'window_bounds.display-1': storedBounds(),
      });

      await controller().restore();

      verify(() => window.setBounds(_saved)).called(1);
      verifyNever(() => window.maximize());
    });

    test('maximizes again when it was closed maximized', () async {
      stubStored({
        'window_bounds.last_display': 'display-1',
        'window_bounds.display-1': storedBounds(isMaximized: true),
      });

      await controller().restore();

      verify(() => window.setBounds(_saved)).called(1);
      verify(() => window.maximize()).called(1);
    });

    test('uses the bounds of the display used last, not another one', () async {
      stubStored({
        'window_bounds.last_display': 'display-2',
        'window_bounds.display-1': storedBounds(),
        'window_bounds.display-2': storedBounds(
          rect: _savedOnSecondary,
          displayId: 'display-2',
        ),
      });

      await controller(displays: const [_primary, _secondary]).restore();

      verify(() => window.setBounds(_savedOnSecondary)).called(1);
    });

    test('keeps the default when the saved display is gone', () async {
      stubStored({
        'window_bounds.last_display': 'display-1',
        'window_bounds.display-1': storedBounds(),
      });

      await controller(displays: const [_secondary]).restore();

      verifyNever(() => window.setBounds(any()));
    });

    test('clamps a saved window that no longer fits its display', () async {
      stubStored({
        'window_bounds.last_display': 'display-1',
        'window_bounds.display-1': storedBounds(
          rect: const Rect.fromLTWH(500, 300, 3500, 2200),
        ),
      });

      await controller().restore();

      verify(
        () => window.setBounds(const Rect.fromLTWH(0, 0, 1920, 1040)),
      ).called(1);
    });

    test(
      'places a value saved before per-display keys on its display',
      () async {
        stubStored({'window_bounds': storedBounds(displayId: null)});

        await controller().restore();

        verify(() => window.setBounds(_saved)).called(1);
      },
    );

    test('ignores saved data it cannot read', () async {
      stubStored({
        'window_bounds.last_display': 'display-1',
        'window_bounds.display-1': '{"x": "not a number"}',
      });

      await controller().restore();

      verifyNever(() => window.setBounds(any()));
    });

    test('still listens when restoring fails', () async {
      when(() => storage.readData(any())).thenThrow(Exception('locked'));

      await controller().restore();

      verify(() => window.addListener(any())).called(1);
    });
  });

  group('clampBoundsToDisplay', () {
    const display = Rect.fromLTWH(0, 0, 1920, 1040);

    test('keeps a window that already fits unchanged', () {
      expect(clampBoundsToDisplay(_saved, display), _saved);
    });

    test('pulls an off-screen window back onto the display', () {
      final clamped = clampBoundsToDisplay(
        const Rect.fromLTWH(5000, 4000, 1000, 700),
        display,
      );

      expect(clamped.left, 920);
      expect(clamped.top, 340);
      expect(clamped.size, const Size(1000, 700));
    });

    test('shrinks a window that is larger than the display', () {
      final clamped = clampBoundsToDisplay(
        const Rect.fromLTWH(0, 0, 3000, 2000),
        display,
      );

      expect(clamped, display);
    });

    test('raises a window smaller than the minimum to it', () {
      final clamped = clampBoundsToDisplay(
        const Rect.fromLTWH(100, 80, 400, 300),
        display,
      );

      expect(clamped.size, kMinimumWindowSize);
    });
  });

  group('saving', () {
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('stores the bounds under the display that holds them', () async {
      controller().onWindowResize();
      await settle();
      await settle();

      final raw =
          verify(
                () =>
                    storage.writeData('window_bounds.display-1', captureAny()),
              ).captured.single
              as String;
      final saved = SavedWindowBounds.tryParse(raw);
      expect(saved?.rect, _saved);
      expect(saved?.isMaximized, isFalse);
      expect(saved?.displayId, 'display-1');
      verify(
        () => storage.writeData('window_bounds.last_display', 'display-1'),
      ).called(1);
    });

    test('stores on the second display when the window moved there', () async {
      when(() => window.getBounds()).thenAnswer((_) async => _savedOnSecondary);

      controller(displays: const [_primary, _secondary]).onWindowMove();
      await settle();
      await settle();

      final raw =
          verify(
                () =>
                    storage.writeData('window_bounds.display-2', captureAny()),
              ).captured.single
              as String;
      expect(SavedWindowBounds.tryParse(raw)?.rect, _savedOnSecondary);
      verify(
        () => storage.writeData('window_bounds.last_display', 'display-2'),
      ).called(1);
    });

    test('does not store a minimized window', () async {
      when(() => window.isMinimized()).thenAnswer((_) async => true);

      controller().onWindowMove();
      await settle();
      await settle();

      verifyNever(() => storage.writeData(any(), any()));
    });

    test('keeps the normal size while maximized', () async {
      stubStored({
        'window_bounds.last_display': 'display-1',
        'window_bounds.display-1': storedBounds(),
      });
      final bounds = controller();
      await bounds.restore();
      when(() => window.isMaximized()).thenAnswer((_) async => true);
      when(
        () => window.getBounds(),
      ).thenAnswer((_) async => const Rect.fromLTWH(0, 0, 1920, 1040));

      bounds.onWindowMaximize();
      await settle();
      await settle();

      final raw =
          verify(
                () =>
                    storage.writeData('window_bounds.display-1', captureAny()),
              ).captured.single
              as String;
      final saved = SavedWindowBounds.tryParse(raw);
      expect(saved?.rect, _saved);
      expect(saved?.isMaximized, isTrue);
    });
  });

  group('SavedWindowBounds', () {
    test('reads a value without a display as a legacy value', () {
      final saved = SavedWindowBounds.tryParse(
        '{"x":100,"y":80,"width":1200,"height":700,"maximized":true}',
      );

      expect(saved?.rect, _saved);
      expect(saved?.isMaximized, isTrue);
      expect(saved?.displayId, isNull);
    });

    test('round-trips the display it was saved on', () {
      final saved = SavedWindowBounds.tryParse(storedBounds());

      expect(saved?.displayId, 'display-1');
      expect(saved?.rect, _saved);
    });
  });
}
