import 'dart:convert';

import 'package:zedu/core/core.dart';

class DownloadView extends ConsumerWidget {
  const DownloadView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final schemaData = {
      '@context': 'https://schema.org',
      '@type': 'SoftwareApplication',
      'name': 'Zedu',
      'description':
          'Download Zedu on iOS, Android, and desktop. Join classes, chat with peers, manage files, and stay updated in one connected learning workspace.',
      'url': '/download',
      'image': '/images/homepage/download/download-hero.png',
      'applicationCategory': 'EducationalApplication',
      'operatingSystem': 'iOS, Android',
      'publisher': {'@type': 'Organization', 'name': 'Zedu', 'url': '/'},
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStructuredData(context, schemaData),
              const SizedBox(height: 32),
              _buildDownloadLinks(context),
              const SizedBox(height: 32),
              _buildAppInfo(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStructuredData(
    BuildContext context,
    Map<String, dynamic> schemaData,
  ) {
    final localColorScheme = Theme.of(context).colorScheme;
    final jsonString = jsonEncode(schemaData).replaceAllMapped(
      RegExp(r'"([a-zA-Z0-9_]+)":'),
      (match) => '${match[1]}: ',
    );

    return Card(
      color: localColorScheme.surface,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          jsonString,
          style: const TextStyle(fontFamily: 'Roboto', fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildDownloadLinks(BuildContext context) {
    return Column(
      children: [
        _buildButton(
          context,
          'App Store',
          Icons.apps,
          () => _launchUrl(context, 'https://apps.apple.com'),
        ),
        const SizedBox(height: 16),
        _buildButton(
          context,
          'Google Play',
          Icons.play_arrow,
          () => _launchUrl(context, 'https://play.google.com'),
        ),
        const SizedBox(height: 16),
        _buildButton(
          context,
          'Desktop',
          Icons.computer,
          () => _launchDesktop(context),
        ),
      ],
    );
  }

  Widget _buildButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: const Text('Zedu - Educational Collaboration Platform'),
      ),
    );
  }

  void _launchUrl(BuildContext ctx, String url) {
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(const SnackBar(content: Text('Opening store...')));
  }

  void _launchDesktop(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Opening desktop download...')),
    );
  }
}
