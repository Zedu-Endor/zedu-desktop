/// What `GET /files/file/{id}/info` reports about a file.
///
/// The files list leaves the channels a file was shared in out, so this is
/// the only place that data comes from.
class WorkspaceFileInfo {
  const WorkspaceFileInfo({
    this.owner = '',
    this.dateUploaded,
    this.lastUpdated,
    this.sharedIn = const [],
  });

  /// Uploader's display name, or empty.
  final String owner;

  final DateTime? dateUploaded;
  final DateTime? lastUpdated;

  /// Names of the channels the file was shared in.
  final List<String> sharedIn;

  /// The names as one string, for the places that show them in a cell.
  String get sharedInLabel => sharedIn.join(', ');

  factory WorkspaceFileInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['shared_in'];
    final sharedIn = raw is List
        ? raw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : const <String>[];

    DateTime? date(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    return WorkspaceFileInfo(
      owner: json['owner']?.toString().trim() ?? '',
      dateUploaded: date(json['date_uploaded']),
      lastUpdated: date(json['last_updated']),
      sharedIn: sharedIn,
    );
  }
}
