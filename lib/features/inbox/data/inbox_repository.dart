import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// How many workspaces are fetched at once. The inbox fans out one request per
/// workspace, so this bounds the burst on a user who belongs to many.
const int kInboxFetchConcurrency = 4;

/// Reads every workspace's conversations and merges them into one list.
///
/// This deliberately reuses [DmRepository], which is already per-organisation,
/// rather than adding a second data path: the only thing the app was missing
/// was asking about more than the selected workspace.
class InboxRepository {
  InboxRepository(this._dms, {this.concurrency = kInboxFetchConcurrency});

  final DmRepository _dms;
  final int concurrency;

  /// Fetches [workspaces] in bounded batches and returns the merged rows,
  /// newest first. A workspace whose request fails is named in
  /// [InboxSnapshot.failedWorkspaces] and does not fail the whole inbox.
  Future<InboxSnapshot> load(List<Workspace> workspaces) async {
    final items = <InboxItem>[];
    final failed = <String>[];

    for (var start = 0; start < workspaces.length; start += concurrency) {
      final batch = workspaces.skip(start).take(concurrency).toList();
      final results = await Future.wait(
        batch.map((workspace) async {
          try {
            final conversations = await _dms.getConversations(
              orgId: workspace.id,
            );
            return (
              workspace: workspace,
              conversations: conversations,
              failed: false,
            );
          } catch (error, stackTrace) {
            AppLogger.w(
              'Inbox: ${workspace.name} could not be read',
              tag: 'InboxRepository',
              error: error,
              stackTrace: stackTrace,
            );
            return (
              workspace: workspace,
              conversations: const <DmConversation>[],
              failed: true,
            );
          }
        }),
      );

      for (final result in results) {
        if (result.failed) {
          failed.add(result.workspace.name);
          continue;
        }
        items.addAll(
          result.conversations.map(
            (conversation) =>
                InboxItem.fromConversation(conversation, result.workspace),
          ),
        );
      }
    }

    items.sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return InboxSnapshot(items: items, failedWorkspaces: failed);
  }
}

final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  return InboxRepository(ref.watch(dmRepositoryProvider));
});
