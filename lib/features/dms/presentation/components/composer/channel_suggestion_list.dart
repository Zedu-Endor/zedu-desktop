import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The channels offered while typing #name in the composer, like web.
class ChannelSuggestionList extends StatelessWidget {
  final List<Channel> suggestions;
  final AppPalette colors;
  final ValueChanged<Channel> onSelect;

  const ChannelSuggestionList({
    super.key,
    required this.suggestions,
    required this.colors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'Channels',
              style: TextStyle(
                color: colors.textHint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 6),
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final channel = suggestions[index];
                final members = channel.membersCount == 1
                    ? '1 member'
                    : '${channel.membersCount} members';
                final secondary = channel.description.trim().isNotEmpty
                    ? channel.description.trim()
                    : members;
                return Semantics(
                  button: true,
                  label: 'Link #${channel.name}',
                  excludeSemantics: true,
                  onTap: () => onSelect(channel),
                  child: InkWell(
                    onTap: () => onSelect(channel),
                    hoverColor: colors.primary.withValues(alpha: 0.07),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            channel.isPrivate
                                ? Icons.lock_outline_rounded
                                : Icons.tag,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  channel.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  secondary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textHint,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
