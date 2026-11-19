import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeStorage extends Fake implements SecureStorageService {
  _FakeStorage({this.token});

  final String? token;
  final values = <String, String>{};

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<String?> readData(String key) async => values[key];

  @override
  Future<void> writeData(String key, String value) async => values[key] = value;
}

void _register(SecureStorageService storage) {
  if (locator.isRegistered<SecureStorageService>()) {
    locator.unregister<SecureStorageService>();
  }
  locator.registerSingleton<SecureStorageService>(storage);
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: AppRouter.welcome,
    routes: [
      GoRoute(
        path: AppRouter.welcome,
        builder: (context, state) => const WelcomeView(),
      ),
      GoRoute(
        path: AppRouter.login,
        builder: (context, state) => const Scaffold(body: Text('Login screen')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  late _FakeStorage storage;

  setUp(() {
    storage = _FakeStorage();
    _register(storage);
  });

  tearDown(() => locator.unregister<SecureStorageService>());

  group('WelcomeView (Ziki #252)', () {
    testWidgets('introduces Zedu and its existing features', (tester) async {
      await _pump(tester, const Size(1440, 900));

      expect(find.text('Welcome to Zedu'), findsOneWidget);
      for (final feature in WelcomeView.features) {
        expect(find.text(feature.title), findsOneWidget);
      }
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('Get Started remembers it and opens the login screen', (
      tester,
    ) async {
      await _pump(tester, const Size(1440, 900));

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('Login screen'), findsOneWidget);
      expect(storage.values[AppRouter.welcomeSeenKey], isNotNull);
    });

    for (final size in const [
      Size(800, 600),
      Size(1024, 700),
      Size(1920, 1080),
    ]) {
      testWidgets(
        'fits a ${size.width.toInt()}x${size.height.toInt()} window',
        (tester) async {
          await _pump(tester, size);

          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('Get Started'),
            100,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Get Started').hitTestable(), findsOneWidget);
        },
      );
    }
  });

  group('AppRouter.resolveStartLocation', () {
    test('a first launch with no session opens the welcome screen', () async {
      expect(
        await AppRouter.resolveStartLocation(_FakeStorage()),
        AppRouter.welcome,
      );
    });

    test('a saved session opens login as before', () async {
      expect(
        await AppRouter.resolveStartLocation(_FakeStorage(token: 't')),
        AppRouter.login,
      );
    });

    test('once seen, the welcome screen is skipped', () async {
      final seen = _FakeStorage()..values[AppRouter.welcomeSeenKey] = 'true';
      expect(await AppRouter.resolveStartLocation(seen), AppRouter.login);
    });

    test('a storage error falls back to login', () async {
      expect(
        await AppRouter.resolveStartLocation(_ThrowingStorage()),
        AppRouter.login,
      );
    });
  });
}

class _ThrowingStorage extends Fake implements SecureStorageService {
  @override
  Future<String?> getAccessToken() async => throw Exception('locked');
}
