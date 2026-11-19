import 'dart:io';

import 'package:zedu/core/core.dart';

import '../../../helpers/helpers.dart';

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

void main() {
  test(
    'first instance is primary, a second launch focuses it and exits',
    () async {
      final port = await _freePort();
      var focusRequests = 0;
      final primary = SingleInstance(
        port: port,
        onSecondLaunch: () async => focusRequests++,
      );
      addTearDown(primary.close);

      expect(await primary.ensurePrimary(), isTrue);
      expect(primary.isPrimary, isTrue);

      final secondary = SingleInstance(port: port);
      addTearDown(secondary.close);
      expect(await secondary.ensurePrimary(), isFalse);
      expect(secondary.isPrimary, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(focusRequests, 1);
    },
  );

  test('closing the primary lets the next launch become primary', () async {
    final port = await _freePort();
    final first = SingleInstance(port: port);
    expect(await first.ensurePrimary(), isTrue);
    await first.close();

    final next = SingleInstance(port: port);
    addTearDown(next.close);
    expect(await next.ensurePrimary(), isTrue);
  });

  test('starts anyway when the port belongs to something else', () async {
    final port = await _freePort();
    final other = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    addTearDown(other.close);

    // Nothing answers the handshake, so the app must not treat this as a
    // second Zedu launch and quit.
    final instance = SingleInstance(port: port);
    addTearDown(instance.close);
    expect(await instance.ensurePrimary(), isTrue);
    expect(instance.isPrimary, isFalse);
  });
}
