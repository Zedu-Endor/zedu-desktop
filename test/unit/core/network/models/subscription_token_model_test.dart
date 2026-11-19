import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('SubscriptionTokenModel', () {
    test('valid JSON deserializes', () {
      final json = {'channel': 'chan', 'token': 'abc'};
      final m = SubscriptionTokenModel.fromJson(json);
      expect(m.channel, 'chan');
      expect(m.token, 'abc');
    });

    test('missing channel falls back to empty string', () {
      final json = {'token': 't'};
      final m = SubscriptionTokenModel.fromJson(json);
      expect(m.channel, '');
    });

    test('missing token falls back to empty string', () {
      final json = {'channel': 'c'};
      final m = SubscriptionTokenModel.fromJson(json);
      expect(m.token, '');
    });

    test('null token falls back to empty string', () {
      final json = {'channel': 'c', 'token': null};
      final m = SubscriptionTokenModel.fromJson(json);
      expect(m.token, '');
    });

    test('toJson produces expected map and round-trips', () {
      final m = SubscriptionTokenModel(channel: 'c', token: 't');
      final json = m.toJson();
      expect(json, {'channel': 'c', 'token': 't'});
      final m2 = SubscriptionTokenModel.fromJson(json);
      expect(m2.channel, m.channel);
      expect(m2.token, m.token);
    });
  });
}
