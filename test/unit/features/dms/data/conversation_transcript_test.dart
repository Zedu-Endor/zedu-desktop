import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

TranscriptMessage _message(
  String sender,
  DateTime sentAt, {
  String content = '',
  List<TranscriptAttachment> attachments = const [],
}) => TranscriptMessage(
  sender: sender,
  sentAt: sentAt,
  content: content,
  attachments: attachments,
);

void main() {
  final exportedAt = DateTime(2026, 11, 5, 12, 30);

  group('transcriptTimestamp', () {
    test('uses a 12-hour clock', () {
      expect(
        transcriptTimestamp(DateTime(2026, 11, 5, 9, 5)),
        '5 Nov 2026, 9:05 AM',
      );
      expect(
        transcriptTimestamp(DateTime(2026, 11, 5, 21, 40)),
        '5 Nov 2026, 9:40 PM',
      );
      expect(
        transcriptTimestamp(DateTime(2026, 11, 6)),
        '6 Nov 2026, 12:00 AM',
      );
      expect(
        transcriptTimestamp(DateTime(2026, 11, 6, 12)),
        '6 Nov 2026, 12:00 PM',
      );
    });
  });

  group('transcriptFileName', () {
    test('slugs the conversation name and stamps the export date', () {
      expect(
        transcriptFileName(
          'Ada Lovelace',
          TranscriptFormat.plainText,
          exportedAt,
        ),
        'ada-lovelace-transcript-2026-11-05.txt',
      );
      expect(
        transcriptFileName(
          '  #team / ops! ',
          TranscriptFormat.markdown,
          exportedAt,
        ),
        'team-ops-transcript-2026-11-05.md',
      );
    });

    test('falls back to a generic name when nothing survives the slug', () {
      expect(
        transcriptFileName('✦', TranscriptFormat.plainText, exportedAt),
        'conversation-transcript-2026-11-05.txt',
      );
    });
  });

  group('formatTranscript plain text', () {
    test('writes a header and each message oldest first', () {
      final text = formatTranscript(
        conversationName: 'Ada Lovelace',
        format: TranscriptFormat.plainText,
        exportedAt: exportedAt,
        messages: [
          _message('You', DateTime(2026, 11, 5, 9, 10), content: 'Second'),
          _message(
            'Ada Lovelace',
            DateTime(2026, 11, 5, 9, 5),
            content: 'First',
          ),
        ],
      );

      expect(text, startsWith('Conversation with Ada Lovelace\n'));
      expect(text, contains('Exported 5 Nov 2026, 12:30 PM · 2 messages'));
      expect(text.indexOf('First'), lessThan(text.indexOf('Second')));
      expect(text, contains('Ada Lovelace · 5 Nov 2026, 9:05 AM'));
      expect(text, contains('You · 5 Nov 2026, 9:10 AM'));
    });

    test('flattens inline Markdown so the file reads as plain text', () {
      final text = formatTranscript(
        conversationName: 'Ada',
        format: TranscriptFormat.plainText,
        exportedAt: exportedAt,
        messages: [
          _message(
            'Ada',
            DateTime(2026, 11, 5, 9),
            content:
                '## Plan\nUse **bold**, *italics*, `code` and '
                '[the docs](https://docs.test) or ~~old~~ notes.',
          ),
        ],
      );

      expect(
        text,
        contains(
          'Plan\nUse bold, italics, code and the docs '
          '(https://docs.test) or old notes.',
        ),
      );
    });

    test('links attachments and names those without a link', () {
      final text = formatTranscript(
        conversationName: 'Ada',
        format: TranscriptFormat.markdown,
        exportedAt: exportedAt,
        messages: [
          _message(
            'Ada',
            DateTime(2026, 11, 5, 9),
            content: 'Here you go',
            attachments: const [
              TranscriptAttachment(
                name: 'report.pdf',
                link: 'https://files.test/report.pdf',
              ),
              TranscriptAttachment(name: 'notes.txt'),
            ],
          ),
        ],
      );

      expect(text, contains('- [report.pdf](https://files.test/report.pdf)'));
      expect(text, contains('- Attachment: notes.txt'));
    });

    test('does not mangle names with underscores', () {
      final text = formatTranscript(
        conversationName: 'Ada',
        format: TranscriptFormat.plainText,
        exportedAt: exportedAt,
        messages: [
          _message('Ada', DateTime(2026, 11, 5, 9), content: 'file_name_here'),
        ],
      );

      expect(text, contains('file_name_here'));
    });

    test('says so when the conversation is empty', () {
      final text = formatTranscript(
        conversationName: 'Ada',
        format: TranscriptFormat.plainText,
        exportedAt: exportedAt,
        messages: const [],
      );

      expect(text, contains('No messages in this conversation.'));
      expect(text, contains('0 messages'));
    });
  });

  group('formatTranscript markdown', () {
    test('keeps the Markdown the chat renders', () {
      final text = formatTranscript(
        conversationName: 'Ada Lovelace',
        format: TranscriptFormat.markdown,
        exportedAt: exportedAt,
        messages: [
          _message(
            'Ada Lovelace',
            DateTime(2026, 11, 5, 9, 5),
            content: '**Hello** there',
          ),
        ],
      );

      expect(text, startsWith('# Conversation with Ada Lovelace\n'));
      expect(text, contains('_Exported 5 Nov 2026, 12:30 PM · 1 message_'));
      expect(text, contains('## Ada Lovelace · 5 Nov 2026, 9:05 AM'));
      expect(text, contains('**Hello** there'));
    });

    test('says so when the conversation is empty', () {
      final text = formatTranscript(
        conversationName: 'Ada',
        format: TranscriptFormat.markdown,
        exportedAt: exportedAt,
        messages: const [],
      );

      expect(text, contains('_No messages in this conversation._'));
    });
  });
}
