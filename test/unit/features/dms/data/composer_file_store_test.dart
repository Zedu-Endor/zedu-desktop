import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

void main() {
  late Directory directory;
  late Set<String> owned;
  late ComposerFileStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('zedu-composer-store-');
    owned = {};
    store = ComposerFileStore(
      temporaryDirectory: directory,
      recordedPaths: owned,
    );
  });

  tearDown(() => directory.delete(recursive: true));

  test('recording paths are created in the store temporary directory', () {
    final path = (store.newRecordingPath() as Success<String>).value;

    expect(
      path,
      startsWith('${directory.path}${Platform.pathSeparator}zedu-voice-'),
    );
    expect(path, endsWith('.m4a'));
    expect(owned, isEmpty);
  });

  test('cleanup deletes a tracked recording and releases ownership', () async {
    final file = await File(
      '${directory.path}/recording.m4a',
    ).writeAsString('audio');
    store.trackRecording(file.path);

    expect(await store.deleteRecording(file.path), isA<Success<void>>());

    expect(await file.exists(), isFalse);
    expect(owned, isEmpty);
  });

  test('cleanup never deletes a file picked by the user', () async {
    final file = await File(
      '${directory.path}/picked.m4a',
    ).writeAsString('audio');

    expect(await store.deleteRecording(file.path), isA<Success<void>>());

    expect(await file.exists(), isTrue);
  });

  test('already-removed and null recordings can be cleaned safely', () async {
    final path = '${directory.path}/missing.m4a';
    store.trackRecording(path);

    expect(await store.deleteRecording(path), isA<Success<void>>());
    expect(await store.deleteRecording(null), isA<Success<void>>());
    expect(owned, isEmpty);
  });

  test('writes clipboard bytes and inspects attachment existence', () async {
    final result = await store.writeTemporaryFile('pasted.png', [1, 2, 3]);
    final path = (result as Success<String>).value;

    expect(await File(path).readAsBytes(), [1, 2, 3]);
    expect((await store.exists(path) as Success<bool>).value, isTrue);
    expect(
      (await store.exists('$path-missing') as Success<bool>).value,
      isFalse,
    );
    expect(owned, isEmpty);
  });

  test('temporary write failures cross the boundary as Failure', () async {
    final file = await File(
      '${directory.path}/not-a-directory',
    ).writeAsString('x');
    final unavailable = ComposerFileStore(
      temporaryDirectory: Directory(file.path),
    );

    expect(
      await unavailable.writeTemporaryFile('pasted.png', [1]),
      isA<Failure<String>>(),
    );
  });
}
