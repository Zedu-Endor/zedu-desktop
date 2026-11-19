import 'package:flutter/gestures.dart';
import 'package:zedu/core/core.dart';

/// The logo plus a "prompt + link" sentence used at the top of the auth
/// screens.
///
/// The row keeps the logo at its intrinsic width and gives the sentence the
/// rest, so a narrow window wraps or ellipsises the text instead of throwing a
/// horizontal overflow. Padding shrinks below [_narrowBreakpoint] because 40px
/// on each side leaves almost nothing for the sentence in a small window.
class AuthHeaderRow extends StatelessWidget {
  const AuthHeaderRow({
    super.key,
    required this.prompt,
    required this.action,
    this.recognizer,
    this.logo,
  });

  final String prompt;
  final String action;
  final GestureRecognizer? recognizer;

  /// Overridable so widget tests do not need the packaged logo asset.
  final Widget? logo;

  static const double _narrowBreakpoint = 480;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w400,
      fontFamily: FontFamily.roboto,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < _narrowBreakpoint;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 40),
          child: Row(
            children: [
              logo ??
                  Image.asset(
                    'assets/pngs/zedu_logo.png',
                    width: 83,
                    height: 31,
                  ),
              SizedBox(width: isNarrow ? 12 : 24),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: prompt,
                    style: style?.copyWith(color: context.colors.textPrimary),
                    children: [
                      TextSpan(
                        text: action,
                        style: style?.copyWith(color: context.colors.primary),
                        recognizer: recognizer,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
