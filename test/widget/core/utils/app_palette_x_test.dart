import 'package:zedu/core/core.dart';

import '../../../helpers/helpers.dart';

class _ColorsProbe extends StatelessWidget {
  const _ColorsProbe({required this.onColors});

  final void Function(AppPalette colors) onColors;

  @override
  Widget build(BuildContext context) {
    // Read colors during build so the probe captures the theme in effect.
    onColors(context.colors);
    return const SizedBox.shrink();
  }
}

Future<AppPalette> _paletteUnder(WidgetTester tester, ThemeData theme) async {
  late AppPalette captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: _ColorsProbe(onColors: (c) => captured = c),
    ),
  );
  return captured;
}

void main() {
  testWidgets('colors returns light palette under a light theme', (
    tester,
  ) async {
    final colors = await _paletteUnder(tester, AppTheme.light);

    expect(identical(colors, AppPalette.light), isTrue);
  });

  testWidgets('colors returns dark palette under a dark theme', (tester) async {
    final colors = await _paletteUnder(tester, AppTheme.dark);

    expect(identical(colors, AppPalette.dark), isTrue);
  });

  test('dark theme is built from the dark palette', () {
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppPalette.dark.brightness, Brightness.dark);
  });
}
