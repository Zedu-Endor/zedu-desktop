import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeRepository implements BuzzMeetingsRepository {
  _FakeRepository(this.result);

  Result<String> result;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<Result<String>> createMeeting() async {
    calls++;
    await gate?.future;
    return result;
  }
}

ProviderContainer _container(
  _FakeRepository repository, {
  String slug = 'acme',
}) {
  final container = ProviderContainer(
    overrides: [
      buzzMeetingsRepositoryProvider.overrideWithValue(repository),
      buzzOrgSlugProvider.overrideWithValue(slug),
      buzzConfigProvider.overrideWithValue(
        const AppConfig(
          apiBaseUrl: 'https://api.zedu.chat/api/v1/',
          usesMockData: false,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starting now links straight into the new meeting', () async {
    final container = _container(_FakeRepository(const Success('abc')));

    final result = await container
        .read(buzzMeetingsProvider.notifier)
        .create(startNow: true);

    expect(
      (result as Success<Uri>).value.toString(),
      'https://zedu.chat/acme/buzz/abc?direct=1',
    );
    expect(container.read(buzzMeetingsProvider), BuzzMeetingAction.none);
  });

  test('a meeting for later gets its plain link', () async {
    final container = _container(_FakeRepository(const Success('abc')));

    final result = await container
        .read(buzzMeetingsProvider.notifier)
        .create(startNow: false);

    expect(
      (result as Success<Uri>).value.toString(),
      'https://zedu.chat/acme/buzz/abc',
    );
  });

  test('shows which action is running and ignores a second one', () async {
    final repository = _FakeRepository(const Success('abc'))
      ..gate = Completer<void>();
    final container = _container(repository);
    final notifier = container.read(buzzMeetingsProvider.notifier);

    final first = notifier.create(startNow: false);
    expect(
      container.read(buzzMeetingsProvider),
      BuzzMeetingAction.createForLater,
    );
    expect(await notifier.create(startNow: true), isA<Failure<Uri>>());

    repository.gate!.complete();
    await first;
    expect(repository.calls, 1);
  });

  test('a server failure gives a message to show', () async {
    final container = _container(
      _FakeRepository(const Failure(ApiFailure(message: 'boom'))),
    );

    final result = await container
        .read(buzzMeetingsProvider.notifier)
        .create(startNow: true);

    expect(
      (result as Failure<Uri>).error.message,
      'Failed to create meeting. Please try again.',
    );
  });

  test('without an organisation nothing is created', () async {
    final repository = _FakeRepository(const Success('abc'));
    final container = _container(repository, slug: '');

    final result = await container
        .read(buzzMeetingsProvider.notifier)
        .create(startNow: true);

    expect(result, isA<Failure<Uri>>());
    expect(repository.calls, 0);
    expect(
      container.read(buzzMeetingsProvider.notifier).linkFor('abc'),
      isNull,
    );
  });
}
