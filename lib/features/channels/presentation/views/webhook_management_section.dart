import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class WebhookManagementSection extends ConsumerWidget {
  const WebhookManagementSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(workspaceProvider).selectedWorkspace?.id;
    return ref
        .watch(webhookManagementPermissionProvider)
        .when(
          loading: () => const CircularProgressIndicator(),
          error: (_, _) => Column(
            children: [
              const Text('Could not check webhook permissions.'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(webhookManagementPermissionProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (allowed) => !allowed || org == null
              ? const Text(
                  'You do not have permission to manage webhooks in this workspace.',
                )
              : _WebhookChannels(key: ValueKey(org), orgId: org),
        );
  }
}

class _WebhookChannels extends ConsumerStatefulWidget {
  const _WebhookChannels({super.key, required this.orgId});
  final String orgId;
  @override
  ConsumerState<_WebhookChannels> createState() => _WebhookChannelsState();
}

class _WebhookChannelsState extends ConsumerState<_WebhookChannels> {
  String? _channelId;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const ProfileSectionHeader(
        title: 'Webhooks',
        subtitle: 'Receive messages from external services in a channel.',
      ),
      const SizedBox(height: 20),
      ref
          .watch(channelProvider)
          .when(
            loading: () => const CircularProgressIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(channelProvider),
              child: const Text('Could not load channels. Retry'),
            ),
            data: (channels) {
              final available = channels
                  .where((c) => c.hasAccess && !c.archived)
                  .toList();
              final selected = available.any((c) => c.id == _channelId)
                  ? _channelId
                  : null;
              if (available.isEmpty) {
                return const Text('No accessible active channels.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(selected),
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Channel'),
                    isExpanded: true,
                    items: [
                      for (final channel in available)
                        DropdownMenuItem(
                          value: channel.id,
                          child: Text('#${channel.name}'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _channelId = value),
                  ),
                  if (selected != null)
                    _WebhookDetails(
                      key: ValueKey(selected),
                      channelId: selected,
                      orgId: widget.orgId,
                    ),
                ],
              );
            },
          ),
    ],
  );
}

class _WebhookDetails extends ConsumerStatefulWidget {
  const _WebhookDetails({
    super.key,
    required this.channelId,
    required this.orgId,
  });
  final String channelId;
  final String orgId;
  @override
  ConsumerState<_WebhookDetails> createState() => _WebhookDetailsState();
}

class _WebhookDetailsState extends ConsumerState<_WebhookDetails> {
  final _name = TextEditingController();
  bool _busy = false;
  bool _revealed = false;
  String? _error;
  bool get _current =>
      mounted &&
      ref.read(workspaceProvider).selectedWorkspace?.id == widget.orgId;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _mutate(Future<void> Function(WebhookRepository) action) async {
    if (_busy || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(webhookRepositoryProvider);
      if (!await repo.canManage(widget.orgId) || !_current) {
        if (mounted && _current) {
          setState(
            () => _error = 'You no longer have permission to manage webhooks.',
          );
        }
        return;
      }
      await action(repo);
      if (_current) {
        _revealed = false;
        ref.invalidate(channelWebhookProvider(widget.channelId));
      }
    } catch (_) {
      // Raw transport errors can contain secret-bearing URLs or response bodies.
      if (mounted && _current) {
        setState(
          () => _error =
              'Could not save webhook changes. Check your permissions and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(WebhookModel webhook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete webhook?'),
        content: const Text(
          'External services using this URL will no longer be able to post to this channel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && _current) {
      await _mutate((repo) => repo.delete(widget.channelId, webhook.id));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Text(_error!, style: TextStyle(color: context.colors.error)),
        ref
            .watch(channelWebhookProvider(widget.channelId))
            .when(
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => Column(
                children: [
                  const Text(
                    'Could not load webhook. Check your access or retry.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      channelWebhookProvider(widget.channelId),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (webhook) => webhook == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No webhook is configured for this channel.',
                        ),
                        TextField(
                          controller: _name,
                          enabled: !_busy,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Webhook name',
                          ),
                        ),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  if (_name.text.trim().isEmpty) {
                                    setState(
                                      () => _error = 'Enter a webhook name.',
                                    );
                                    return;
                                  }
                                  _mutate(
                                    (repo) => repo.create(
                                      widget.channelId,
                                      _name.text,
                                    ),
                                  );
                                },
                          child: Text(_busy ? 'Creating…' : 'Create webhook'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(webhook.name),
                        Text(webhook.isActive ? 'Active' : 'Inactive'),
                        const SizedBox(height: 12),
                        if (_revealed)
                          SelectableText(webhook.url)
                        else
                          const Text('Webhook URL: ••••••••'),
                        Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              onPressed: _busy || webhook.url.isEmpty
                                  ? null
                                  : () =>
                                        setState(() => _revealed = !_revealed),
                              child: Text(
                                _revealed ? 'Hide URL' : 'Reveal URL',
                              ),
                            ),
                            TextButton(
                              onPressed: _busy || webhook.url.isEmpty
                                  ? null
                                  : () async {
                                      try {
                                        await Clipboard.setData(
                                          ClipboardData(text: webhook.url),
                                        );
                                        if (context.mounted && _current) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Webhook URL copied.',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (_) {
                                        if (mounted && _current) {
                                          setState(
                                            () => _error =
                                                'Could not copy webhook URL.',
                                          );
                                        }
                                      }
                                    },
                              child: const Text('Copy URL'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : () => _delete(webhook),
                              child: Text(_busy ? 'Saving…' : 'Delete webhook'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
      ],
    ),
  );
}
