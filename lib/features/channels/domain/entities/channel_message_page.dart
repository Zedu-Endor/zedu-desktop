import 'package:zedu/features/features.dart';

/// One page of a channel's history, newest first.
class ChannelMessagePage {
  const ChannelMessagePage({required this.messages, required this.hasMore});

  final List<ChannelMessage> messages;

  /// Whether the backend has an older page after this one.
  final bool hasMore;
}
