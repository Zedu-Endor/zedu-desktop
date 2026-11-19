/// A reaction on a channel or DM message.
class ReactionModel {
  const ReactionModel({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    this.userName,
    this.createdAt,
  });

  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final String? userName;
  final DateTime? createdAt;

  factory ReactionModel.fromJson(Map<String, dynamic> json) {
    return ReactionModel(
      id: _asString(json['id']),
      messageId: _asString(json['messageId'] ?? json['message_id']),
      userId: _asString(json['userId'] ?? json['user_id']),
      emoji: _asString(json['emoji'] ?? json['reaction']),
      userName: _asNullableString(json['userName'] ?? json['user_name']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'messageId': messageId,
    'userId': userId,
    'emoji': emoji,
    if (userName != null) 'userName': userName,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}

String _asString(Object? value) => value?.toString() ?? '';

String? _asNullableString(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
