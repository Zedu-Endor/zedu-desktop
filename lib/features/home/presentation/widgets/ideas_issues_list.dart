import 'package:zedu/core/core.dart';

/// A widget that displays a list of ideas and issues with loading, error, and
/// empty states.
///
/// Shows:
/// - A loading indicator while data is being fetched
/// - An error state with a retry button when loading fails
/// - An empty state with an illustration when there are no ideas or issues
/// - The list of ideas/issues when data is available
class IdeasIssuesList extends ConsumerStatefulWidget {
  const IdeasIssuesList({super.key});

  @override
  ConsumerState<IdeasIssuesList> createState() => _IdeasIssuesListState();
}

class _IdeasIssuesListState extends ConsumerState<IdeasIssuesList> {
  bool _isLoading = true;
  String? _error;
  List<String> _items = [];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isLoading) {
      return _buildLoadingState(colors);
    }

    if (_error != null) {
      return _buildErrorState(colors);
    }

    if (_items.isEmpty) {
      return _buildEmptyState(colors);
    }

    return _buildList(colors);
  }

  /// Shows a loading state with a centered loading indicator.
  Widget _buildLoadingState(AppPalette colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows an error state with a retry button.
  Widget _buildErrorState(AppPalette colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, color: colors.error, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load ideas & issues',
            style: context.textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Something went wrong.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _reload,
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  /// Shows an empty state when there are no ideas or issues.
  Widget _buildEmptyState(AppPalette colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_outlined, color: colors.primary, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'No ideas or issues yet',
            style: context.textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to create an idea or report an issue.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Shows the list of ideas and issues.
  Widget _buildList(AppPalette colors) {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(item),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }

  /// Simulates loading data. In a real app, this would call an API.
  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Simulate network delay
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Simulate random success/failure for demonstration
    final success = DateTime.now().millisecond % 3 != 0;

    if (!mounted) return;

    setState(() {
      if (success) {
        _isLoading = false;
        _items = [
          'Improve DM search functionality',
          'Add keyboard shortcuts for common actions',
          'Improve voice note recording quality',
          'Add dark mode support',
          'Improve file attachment handling',
        ];
      } else {
        _isLoading = false;
        _error = 'Failed to load. Please try again.';
      }
    });
  }
}
