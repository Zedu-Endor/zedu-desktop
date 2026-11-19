import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/home/presentation/widgets/search_panel.dart';

void main() {
  const base = TextStyle();
  const match = TextStyle(fontWeight: FontWeight.bold);

  test('marks every case-insensitive match', () {
    final span = highlightMatches(
      'Budget first, then the budget',
      'budget',
      base: base,
      match: match,
    );
    final parts = span.children!.cast<TextSpan>();

    expect(parts.map((part) => part.text), [
      'Budget',
      ' first, then the ',
      'budget',
    ]);
    expect(parts.where((part) => part.style == match), hasLength(2));
  });

  test('leaves text alone when the query is blank', () {
    final span = highlightMatches('Hello', ' ', base: base, match: match);
    expect(span.text, 'Hello');
    expect(span.children, isNull);
  });
}
