/// What people a file is shared with can do with it.
enum FileSharePermission {
  view('view', 'Can view'),
  edit('edit', 'Can edit');

  const FileSharePermission(this.apiValue, this.label);

  /// The `permission_type` the share endpoint takes.
  final String apiValue;
  final String label;
}

/// Who can open a shared file.
enum FileShareAccess {
  invited('private', 'Only those invited'),
  anyoneWithLink('public', 'Anyone with link');

  const FileShareAccess(this.apiValue, this.label);

  /// The `access_type` the share endpoint takes.
  final String apiValue;
  final String label;
}

/// How sending a shared file to one person by direct message went.
class FileShareRecipientResult {
  final String userId;
  final String username;
  final bool success;
  final String error;

  const FileShareRecipientResult({
    required this.userId,
    this.username = '',
    this.success = false,
    this.error = '',
  });

  factory FileShareRecipientResult.fromJson(Map<String, dynamic> json) =>
      FileShareRecipientResult(
        userId: json['user_id']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        success: json['success'] == true,
        error: json['error']?.toString().trim() ?? '',
      );
}

/// The share `POST /files/{id}/share` made.
class FileShareResult {
  final String shareLink;

  /// Ids of the people the file was sent to by direct message.
  final List<String> sentTo;

  /// One entry per recipient, when the server reports them.
  final List<FileShareRecipientResult> recipients;

  const FileShareResult({
    this.shareLink = '',
    this.sentTo = const [],
    this.recipients = const [],
  });

  /// The recipients the file could not be sent to.
  List<FileShareRecipientResult> get failures => [
    for (final r in recipients)
      if (!r.success) r,
  ];

  factory FileShareResult.fromJson(Map<String, dynamic> json) {
    final sent = json['dms_sent'];
    final info = json['recipients_info'];
    return FileShareResult(
      shareLink: json['share_link']?.toString() ?? '',
      sentTo: [
        if (sent is List)
          for (final id in sent)
            if (id != null) id.toString(),
      ],
      recipients: [
        if (info is List)
          for (final r in info.whereType<Map<dynamic, dynamic>>())
            FileShareRecipientResult.fromJson(Map<String, dynamic>.from(r)),
      ],
    );
  }
}
