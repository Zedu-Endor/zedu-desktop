import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// How sharing a file went.
class FileShareOutcome {
  /// Whether it reached at least one person. When false, nothing was sent and
  /// [message] says why.
  final bool shared;

  /// Whether it reached everyone it was meant for.
  final bool complete;

  /// What to tell the person.
  final String message;

  const FileShareOutcome._(this.shared, this.complete, this.message);

  const FileShareOutcome.failed(String message) : this._(false, false, message);
}

/// Ids of the files being shared.
class FileSharesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Shares [file] with [recipients] by direct message, as the web app does.
  Future<FileShareOutcome> share(
    WorkspaceFile file, {
    required List<OrgMember> recipients,
    required FileSharePermission permission,
    required FileShareAccess access,
    String note = '',
  }) async {
    if (recipients.isEmpty) {
      return const FileShareOutcome.failed('Add at least one person.');
    }
    if (state.contains(file.id)) {
      return const FileShareOutcome.failed(
        'This file is already being shared.',
      );
    }

    state = {...state, file.id};
    final result = await ref
        .read(filesRepositoryProvider)
        .shareFile(
          fileId: file.id,
          recipientIds: [for (final r in recipients) r.id],
          permission: permission,
          access: access,
          note: note.trim(),
        );
    if (ref.mounted) state = {...state}..remove(file.id);

    switch (result) {
      case Failure(:final error):
        return FileShareOutcome.failed(
          'Could not share ${file.name}. ${_reason(error)}',
        );
      case Success(:final value):
        return _outcome(file, recipients, value);
    }
  }

  static FileShareOutcome _outcome(
    WorkspaceFile file,
    List<OrgMember> recipients,
    FileShareResult result,
  ) {
    final names = {for (final r in recipients) r.id: r.displayName};
    final failures = [
      for (final f in result.failures)
        '${names[f.userId] ?? (f.username.isNotEmpty ? f.username : 'A recipient')}: '
            '${f.error.isNotEmpty ? f.error : 'not sent'}',
    ];
    // Only server-confirmed deliveries count. An empty reply confirms
    // nothing, so it sends to nobody instead of assuming full success.
    final sent = result.sentTo.isNotEmpty
        ? result.sentTo.length
        : result.recipients.where((r) => r.success).length;
    final total = sent + failures.length;

    if (sent <= 0) {
      return FileShareOutcome.failed(
        failures.isEmpty
            ? 'Could not share ${file.name}. Please try again.'
            : 'Could not share ${file.name}. ${failures.join('; ')}.',
      );
    }
    if (failures.isNotEmpty) {
      return FileShareOutcome._(
        true,
        false,
        'Shared ${file.name} with $sent of $total people. '
        '${failures.join('; ')}.',
      );
    }
    final who = sent == 1 && recipients.length == 1
        ? recipients.single.displayName
        : '$sent ${sent == 1 ? 'person' : 'people'}';
    return FileShareOutcome._(
      true,
      true,
      'Shared ${file.name} with $who by direct message.',
    );
  }

  static String _reason(ApiFailure error) => switch (error.kind) {
    ApiFailureKind.forbidden => 'Only its owner can share it.',
    ApiFailureKind.unknown || ApiFailureKind.parsing => 'Please try again.',
    _ => error.friendlyMessage,
  };
}
