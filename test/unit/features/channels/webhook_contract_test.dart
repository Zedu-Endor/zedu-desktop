import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/channels/data/models/webhook_model.dart';

void main() {
  test('parses the incoming webhook API used by web', () {
    final webhook = WebhookModel.fromJson({
      'id': 'w1',
      'channel_id': 'c1',
      'webhook_name': 'Builds',
      'webhook_url': 'https://example.com/secret',
      'webhook_slug': 'slug',
      'status': 'active',
    });
    expect(webhook.name, 'Builds');
    expect(webhook.channelId, 'c1');
    expect(webhook.url, 'https://example.com/secret');
    expect(webhook.isActive, isTrue);
    expect(WebhookModel.fromJson({'status': 'inactive'}).isActive, isFalse);
  });
}
