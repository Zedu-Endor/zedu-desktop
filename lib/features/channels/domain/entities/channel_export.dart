/// Where a channel history export stands on the server.
enum ChannelExportStatus { pending, inProgress, completed, failed }

/// One export of a channel's history, as `POST /channels/{id}/export` and
/// `GET /channels/{id}/export/status` return it.
class ChannelExport {
  const ChannelExport({
    required this.id,
    required this.status,
    this.fileUrl,
    this.errorMessage,
  });

  final String id;
  final ChannelExportStatus status;

  /// The file to download, once [status] is completed.
  final String? fileUrl;
  final String? errorMessage;

  bool get isRunning =>
      status == ChannelExportStatus.pending ||
      status == ChannelExportStatus.inProgress;

  factory ChannelExport.fromJson(Map<String, dynamic> json) {
    final fileUrl = json['file_url'] as String?;
    final error = json['error_message'] as String?;
    return ChannelExport(
      id: json['id'] as String? ?? '',
      status: switch (json['status']) {
        'pending' => ChannelExportStatus.pending,
        'in_progress' => ChannelExportStatus.inProgress,
        'completed' => ChannelExportStatus.completed,
        _ => ChannelExportStatus.failed,
      },
      fileUrl: fileUrl == null || fileUrl.isEmpty ? null : fileUrl,
      errorMessage: error == null || error.isEmpty ? null : error,
    );
  }
}
