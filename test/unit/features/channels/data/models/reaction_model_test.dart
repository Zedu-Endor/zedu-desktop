import 'package:zedu/features/features.dart';
import 'package:zedu/features/channels/data/models/reaction_model.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  test('ReactionModel parses a camelCase reaction', () {
    final model = ReactionModel.fromJson({
      'id': 'r1',
      'messageId': 'm1',
      'userId': 'u1',
      'emoji': '👍',
      'userName': 'Alice',
      'createdAt': '2026-11-05T10:00:00.000Z',
    });
    expect(model.id, 'r1');
    expect(model.messageId, 'm1');
    expect(model.userId, 'u1');
    expect(model.emoji, '👍');
    expect(model.userName, 'Alice');
    expect(model.createdAt, isNotNull);
  });

  test('ReactionModel parses backend snake_case fields', () {
    final model = ReactionModel.fromJson({
      'id': 'r2',
      'message_id': 'm2',
      'user_id': 'u2',
      'reaction': '❤️',
    });
    expect(model.emoji, '❤️');
    expect(model.userName, isNull);
    expect(model.createdAt, isNull);
  });

  test('ReactionModel round-trips through toJson', () {
    final model = ReactionModel(
      id: 'r3',
      messageId: 'm3',
      userId: 'u3',
      emoji: '🎉',
      userName: 'Bob',
      createdAt: DateTime.utc(2026, 11, 5),
    );
    final json = model.toJson();
    final parsed = ReactionModel.fromJson(json);
    expect(parsed.id, model.id);
    expect(parsed.emoji, model.emoji);
    expect(parsed.userName, model.userName);
  });
}
