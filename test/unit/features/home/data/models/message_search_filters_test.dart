import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  // A Thursday afternoon, local time.
  final now = DateTime(2026, 11, 5, 15, 30);

  String query(String text, MessageSearchFilters filters) =>
      buildMessageSearchQuery(text, filters, now: now);

  group('buildMessageSearchQuery (#2825)', () {
    test('lower-cases and trims the typed words, with no filters', () {
      expect(
        query('  Release NOTES ', MessageSearchFilters.none),
        'release notes',
      );
    });

    test('adds from: and in: tokens, quoting names with spaces', () {
      final filters = const MessageSearchFilters(
        from: 'Ada Lovelace',
        channel: 'general',
      );
      expect(query('deploy', filters), 'deploy from:"Ada Lovelace" in:general');
    });

    test('escapes quotes inside a quoted name', () {
      expect(messageSearchToken('Ada "the" Count'), r'"Ada \"the\" Count"');
      expect(messageSearchToken('   '), '');
    });

    test('keeps the filter casing while the words are lower-cased', () {
      final filters = const MessageSearchFilters(channel: 'Design-Team');
      expect(query('LOGO', filters), 'logo in:Design-Team');
    });

    test('searches with filters alone when nothing is typed', () {
      final filters = const MessageSearchFilters(from: 'Ada');
      expect(query('', filters), 'from:Ada');
    });

    test('turns each date choice into on:, or after: and before:', () {
      String date(MessageSearchDate value) =>
          query('x', MessageSearchFilters.none.withDate(value));

      expect(date(MessageSearchDate.anyTime), 'x');
      expect(date(MessageSearchDate.today), 'x on:2026-11-05');
      expect(date(MessageSearchDate.yesterday), 'x on:2026-11-04');
      expect(
        date(MessageSearchDate.last7Days),
        'x after:2026-10-29 before:2026-11-05',
      );
      expect(
        date(MessageSearchDate.last30Days),
        'x after:2026-10-06 before:2026-11-05',
      );
      expect(
        date(MessageSearchDate.last12Months),
        'x after:2025-11-05 before:2026-11-05',
      );
    });

    test('yesterday crosses a month boundary', () {
      expect(
        buildMessageSearchQuery(
          '',
          MessageSearchFilters.none.withDate(MessageSearchDate.yesterday),
          now: DateTime(2026, 3, 1, 9),
        ),
        'on:2026-02-28',
      );
    });
  });

  group('MessageSearchFilters', () {
    test('counts the filters that are on, ignoring blank names', () {
      expect(MessageSearchFilters.none.activeCount, 0);
      expect(const MessageSearchFilters(from: '  ').activeCount, 0);
      expect(
        const MessageSearchFilters(
          from: 'Ada',
          channel: 'general',
          date: MessageSearchDate.today,
        ).activeCount,
        3,
      );
    });

    test('changing one filter keeps the others', () {
      final filters = const MessageSearchFilters(
        from: 'Ada',
        channel: 'general',
      ).withDate(MessageSearchDate.last7Days).withFrom(null);
      expect(filters.from, isNull);
      expect(filters.channel, 'general');
      expect(filters.date, MessageSearchDate.last7Days);
    });
  });
}
