import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Opens the file at [url]; returns whether it could.
typedef ExportLauncher = Future<bool> Function(Uri url);

Future<bool> _launchExternally(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Exports a channel's history: starts the export, waits for the server to
/// prepare it, then offers the file to download.
class ChannelExportDialog extends ConsumerStatefulWidget {
  const ChannelExportDialog({
    super.key,
    required this.channel,
    this.pollInterval = const Duration(seconds: 3),
    this.maxWait = const Duration(minutes: 5),
    this.launcher = _launchExternally,
  });

  final Channel channel;
  final Duration pollInterval;

  /// How long to wait for the server before giving up.
  final Duration maxWait;
  final ExportLauncher launcher;

  @override
  ConsumerState<ChannelExportDialog> createState() =>
      _ChannelExportDialogState();
}

class _ChannelExportDialogState extends ConsumerState<ChannelExportDialog> {
  Timer? _poll;

  /// Time spent waiting between status checks since the export started.
  Duration _waited = Duration.zero;
  String? _fileUrl;
  String? _error;

  bool get _preparing => _fileUrl == null && _error == null;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _fileUrl = null;
      _error = null;
    });
    _start();
  }

  Future<void> _start() async {
    _poll?.cancel();
    _waited = Duration.zero;
    final result = await ref
        .read(channelRepositoryProvider)
        .startChannelExport(widget.channel.id);
    _handle(result);
  }

  Future<void> _checkStatus() async {
    final result = await ref
        .read(channelRepositoryProvider)
        .fetchChannelExportStatus(widget.channel.id);
    _handle(result);
  }

  void _handle(Result<ChannelExport> result) {
    if (!mounted) return;
    switch (result) {
      case Failure<ChannelExport>(:final error):
        setState(
          () => _error = error.message.isEmpty
              ? "Couldn't export #${widget.channel.name}."
              : error.message,
        );
      case Success<ChannelExport>(:final value):
        if (value.status == ChannelExportStatus.completed &&
            value.fileUrl != null) {
          setState(() => _fileUrl = value.fileUrl);
        } else if (value.isRunning) {
          if (_waited >= widget.maxWait) {
            setState(
              () => _error =
                  'The export is taking longer than expected. Try again later.',
            );
          } else {
            _waited += widget.pollInterval;
            _poll = Timer(widget.pollInterval, _checkStatus);
          }
        } else {
          setState(
            () => _error =
                value.errorMessage ??
                "Couldn't export #${widget.channel.name}.",
          );
        }
    }
  }

  Future<void> _download() async {
    final uri = Uri.tryParse(_fileUrl ?? '');
    final opened = uri != null && await widget.launcher(uri);
    if (!mounted) return;
    if (opened) {
      Navigator.pop(context);
    } else {
      setState(() {
        _fileUrl = null;
        _error = "Couldn't open the export file.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Widget body;
    if (_preparing) {
      body = Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Preparing your export of #${widget.channel.name}…',
              style: context.textTheme.bodyMedium,
            ),
          ),
        ],
      );
    } else if (_fileUrl != null) {
      body = Text(
        'Your export of #${widget.channel.name} is ready.',
        style: context.textTheme.bodyMedium,
      );
    } else {
      body = Text(
        _error!,
        style: context.textTheme.bodyMedium?.copyWith(color: colors.error),
      );
    }

    return AlertDialog(
      title: Text('Export #${widget.channel.name}'),
      content: SizedBox(width: 400, child: body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (_fileUrl != null)
          TextButton(onPressed: _download, child: const Text('Download')),
        if (_error != null)
          TextButton(onPressed: _retry, child: const Text('Try again')),
      ],
    );
  }
}
