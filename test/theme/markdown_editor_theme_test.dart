import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/theme/markdown_editor_theme.dart';

void main() {
  group('MarkdownEditorTheme.light()', () {
    late MarkdownEditorTheme theme;

    setUp(() {
      theme = MarkdownEditorTheme.light();
    });

    test('has 6 heading styles', () {
      expect(theme.headingStyles.length, equals(6));
    });

    test('heading sizes decrease from H1 to H6', () {
      for (var i = 0; i < 5; i++) {
        expect(
          theme.headingStyles[i].fontSize!,
          greaterThanOrEqualTo(theme.headingStyles[i + 1].fontSize!),
        );
      }
    });

    test('bold style has bold weight', () {
      expect(theme.boldStyle.fontWeight, equals(FontWeight.bold));
    });

    test('italic style has italic font style', () {
      expect(theme.italicStyle.fontStyle, equals(FontStyle.italic));
    });

    test('boldItalic has both bold and italic', () {
      expect(theme.boldItalicStyle.fontWeight, equals(FontWeight.bold));
      expect(theme.boldItalicStyle.fontStyle, equals(FontStyle.italic));
    });

    test('inline code style uses monospace', () {
      expect(theme.inlineCodeStyle.fontFamily, equals('monospace'));
    });

    test('strikethrough has lineThrough decoration', () {
      expect(
        theme.strikethroughStyle.decoration,
        equals(TextDecoration.lineThrough),
      );
    });

    test('hidden syntax style is near-invisible', () {
      expect(theme.hiddenSyntaxStyle.fontSize, equals(0.01));
      expect(theme.hiddenSyntaxStyle.color, equals(const Color(0x00000000)));
    });

    test('syntax delimiter style is visible but muted', () {
      expect(theme.syntaxDelimiterStyle.color, equals(const Color(0xFFAAAAAA)));
      expect(theme.syntaxDelimiterStyle.fontSize, isNot(equals(0.01)));
    });

    test('has white background', () {
      expect(theme.backgroundColor, equals(const Color(0xFFFFFFFF)));
    });
  });

  group('MarkdownEditorTheme.dark()', () {
    late MarkdownEditorTheme theme;

    setUp(() {
      theme = MarkdownEditorTheme.dark();
    });

    test('has 6 heading styles', () {
      expect(theme.headingStyles.length, equals(6));
    });

    test('has dark background', () {
      expect(theme.backgroundColor, equals(const Color(0xFF1E1E1E)));
    });

    test('base text is light colored', () {
      expect(theme.baseStyle.color, equals(const Color(0xFFE0E0E0)));
    });

    test('hidden syntax style is near-invisible', () {
      expect(theme.hiddenSyntaxStyle.fontSize, equals(0.01));
    });
  });

  group('copyWith()', () {
    test('returns copy with overridden fields', () {
      final theme = MarkdownEditorTheme.light();
      final modified = theme.copyWith(
        cursorColor: const Color(0xFFFF0000),
        backgroundColor: const Color(0xFF000000),
      );

      expect(modified.cursorColor, equals(const Color(0xFFFF0000)));
      expect(modified.backgroundColor, equals(const Color(0xFF000000)));
      // Unchanged fields preserved
      expect(modified.baseStyle, equals(theme.baseStyle));
      expect(modified.boldStyle, equals(theme.boldStyle));
    });

    test('returns identical theme when no overrides given', () {
      final theme = MarkdownEditorTheme.light();
      final copy = theme.copyWith();
      expect(copy.baseStyle, equals(theme.baseStyle));
      expect(copy.cursorColor, equals(theme.cursorColor));
      expect(copy.headingStyles.length, equals(theme.headingStyles.length));
    });
  });
}
