class Workspace {
  final String id;
  final String name;
  final String avatar;
  final int unreadCount;
  final int membersCount;

  const Workspace({
    required this.id,
    required this.name,
    required this.avatar,
    this.unreadCount = 0,
    this.membersCount = 0,
  });

  /// What the organisation switcher shows under the name, e.g. "1 member".
  String get membersLabel =>
      membersCount == 1 ? '1 member' : '$membersCount members';

  Workspace copyWith({
    String? id,
    String? name,
    String? avatar,
    int? unreadCount,
    int? membersCount,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      unreadCount: unreadCount ?? this.unreadCount,
      membersCount: membersCount ?? this.membersCount,
    );
  }
}
