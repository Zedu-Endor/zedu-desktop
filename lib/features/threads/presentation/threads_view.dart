import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Organisation-wide entry point; loading is scoped to the selected workspace.
class ThreadsView extends ConsumerWidget {
  const ThreadsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Row(
        children: [
          AppSidebarRail(
            activeType: null,
            threadsSelected: true,
            onTypeSelected: (type) {
              ref.read(homeSidebarProvider.notifier).setType(type);
              context.go(AppRouter.home);
            },
          ),
          const Expanded(child: ThreadsInboxBody()),
        ],
      ),
    ),
  );
}

class ThreadsInboxBody extends ConsumerWidget {
  const ThreadsInboxBody({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(threadsInboxProvider);
    final actions = ref.read(threadsInboxProvider.notifier);
    final orgId = ref.watch(currentOrgIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Text('Threads', style: context.textTheme.headlineSmall),
              ),
              if (state.unseenCount > 0)
                Semantics(
                  label: '${state.unseenCount} unread threads',
                  child: Chip(label: Text('${state.unseenCount} unread')),
                ),
              IconButton(
                tooltip: 'Refresh threads',
                onPressed: orgId.isEmpty || state.loading
                    ? null
                    : actions.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (orgId.isEmpty)
          const Expanded(
            child: Center(
              child: Text('Select a workspace to see your threads.'),
            ),
          )
        else if (state.loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        Text(state.error!, semanticsLabel: state.error),
                        TextButton(
                          onPressed: state.loadingMore
                              ? null
                              : state.threads.isEmpty
                              ? actions.refresh
                              : actions.loadMore,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                if (state.threads.isEmpty && state.error == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.forum_outlined, size: 48),
                        SizedBox(height: 16),
                        Text('No threads yet'),
                        SizedBox(height: 8),
                        Text(
                          'Discussions you participate in will appear here.',
                        ),
                      ],
                    ),
                  ),
                for (final thread in state.threads)
                  Card(
                    key: ValueKey('thread-${thread.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            thread.channelName.isEmpty
                                ? 'Conversation'
                                : '#${thread.channelName}',
                            style: context.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final message in thread.messages.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${message.author}: ${threadText(message.content)}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                  thread.channelName.isEmpty
                                      ? 'Thread'
                                      : '#${thread.channelName}',
                                ),
                                content: SizedBox(
                                  width: 560,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (final message in thread.messages)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: SelectableText(
                                              '${message.author}\n${threadText(message.content)}',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            ),
                            child: const Text('Read discussion'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (state.loadingMore)
                  const Center(child: CircularProgressIndicator())
                else if (state.hasMore && state.error == null)
                  Center(
                    child: TextButton(
                      onPressed: actions.loadMore,
                      child: const Text('Load more threads'),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Match the existing DM search's plain-text treatment of backend HTML.
String threadText(String content) => content
    .replaceAll(RegExp(r'</?(p|div|li|ul|ol|br|blockquote|pre)\b[^>]*>'), ' ')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
