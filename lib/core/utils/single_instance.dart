import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Keeps a single desktop process in charge of the window.
///
/// The first instance binds a loopback port and listens for launches. A later
/// launch cannot bind the port, asks the primary instance to show its window
/// and reports that it should exit, so the user never gets a second window.
///
/// If the port is taken but does not answer the handshake, the app still
/// starts: a stray process must not stop Zedu from launching.
class SingleInstance {
  SingleInstance({this.port = defaultPort, this.onSecondLaunch});

  /// Loopback port used to hand a second launch to the primary instance.
  static const defaultPort = 47823;

  static const _showMessage = 'zedu-show';
  static const _replyMessage = 'zedu-primary';

  final int port;

  /// Called in the primary instance when another launch asks it to show.
  final Future<void> Function()? onSecondLaunch;

  ServerSocket? _server;
  StreamSubscription<Socket>? _subscription;

  bool get isPrimary => _server != null;

  /// Returns `true` when this process should run, or `false` when another
  /// instance already owns the window (and has been asked to show it).
  Future<bool> ensurePrimary() async {
    if (_server != null) return true;
    try {
      final server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      _server = server;
      _subscription = server.listen(_handleLaunch);
      return true;
    } on SocketException {
      final notified = await _notifyPrimary();
      return !notified;
    }
  }

  void _handleLaunch(Socket socket) {
    final buffer = <int>[];
    late StreamSubscription<List<int>> subscription;
    subscription = socket.listen(
      (data) {
        buffer.addAll(data);
        if (!utf8.decode(buffer, allowMalformed: true).contains(_showMessage)) {
          return;
        }
        socket.write(_replyMessage);
        unawaited(
          socket.flush().whenComplete(() {
            socket.destroy();
            unawaited(subscription.cancel());
          }),
        );
        final callback = onSecondLaunch;
        if (callback != null) unawaited(callback());
      },
      onError: (_) => socket.destroy(),
      cancelOnError: true,
    );
  }

  Future<bool> _notifyPrimary() async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 750),
      );
      socket.write(_showMessage);
      await socket.flush();
      final reply = await socket.first.timeout(
        const Duration(milliseconds: 750),
        onTimeout: () => Uint8List(0),
      );
      socket.destroy();
      return utf8.decode(reply, allowMalformed: true).contains(_replyMessage);
    } catch (_) {
      return false;
    }
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    await _server?.close();
    _server = null;
  }
}
