import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitparser/petitparser.dart';

import 'package:markdowner/markdowner.dart';

/// Extract all text from a TextSpan tree recursively.
String extractAllText(TextSpan span) {
  final buffer = StringBuffer();
  _collectText(span, buffer);
  return buffer.toString();
}

void _collectText(TextSpan span, StringBuffer buffer) {
  if (span.text != null) {
    buffer.write(span.text);
  }
  if (span.children != null) {
    for (final child in span.children!) {
      _collectText(child as TextSpan, buffer);
    }
  }
}

void main() {
  late MarkdownRenderEngine engine;
  late MarkdownEditorTheme theme;
  late Parser parser;

  setUp(() {
    theme = MarkdownEditorTheme.light();
    engine = MarkdownRenderEngine(theme: theme);
    parser = MarkdownParserDefinition().build();
  });

  MarkdownDocument parse(String source) {
    final result = parser.parse(source);
    if (result is Failure) {
      fail('Parse failed at ${result.position}: ${result.message}');
    }
    return (result as Success).value as MarkdownDocument;
  }

  group('text invariant', () {
    /// Verifies that extracted text exactly matches block source text.
    void verifyTextInvariant(String source) {
      final doc = parse(source);
      for (final block in doc.blocks) {
        final revealed = engine.buildRevealedSpan(block, theme.baseStyle);
        expect(
          extractAllText(revealed),
          equals(block.sourceText),
          reason: 'Revealed span text must match source for: ${block.sourceText}',
        );
        final collapsed = engine.buildCollapsedSpan(block, theme.baseStyle);
        expect(
          extractAllText(collapsed),
          equals(block.sourceText),
          reason: 'Collapsed span text must match source for: ${block.sourceText}',
        );
      }
    }

    test('paragraph with plain text', () {
      verifyTextInvariant('Hello world\n');
    });

    test('heading', () {
      verifyTextInvariant('# Heading\n');
    });

    test('heading levels 1-6', () {
      verifyTextInvariant('# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6\n');
    });

    test('paragraph with bold', () {
      verifyTextInvariant('Hello **bold** world\n');
    });

    test('paragraph with italic', () {
      verifyTextInvariant('Hello *italic* world\n');
    });

    test('paragraph with bold italic', () {
      verifyTextInvariant('Hello ***bolditalic*** world\n');
    });

    test('paragraph with inline code', () {
      verifyTextInvariant('Hello `code` world\n');
    });

    test('paragraph with double backtick code', () {
      verifyTextInvariant('Hello ``co`de`` world\n');
    });

    test('paragraph with strikethrough', () {
      verifyTextInvariant('Hello ~~strike~~ world\n');
    });

    test('paragraph with escaped char', () {
      verifyTextInvariant('Hello \\* world\n');
    });

    test('thematic break', () {
      verifyTextInvariant('---\n');
    });

    test('blank line', () {
      verifyTextInvariant('\n');
    });

    test('mixed document', () {
      verifyTextInvariant('# Title\n\nSome **bold** and *italic* `code`\n---\n');
    });

    test('no trailing newline', () {
      verifyTextInvariant('Hello world');
    });

    test('paragraph with link', () {
      verifyTextInvariant('See [here](https://example.com) for details\n');
    });

    test('paragraph with link and title', () {
      verifyTextInvariant('[click](url "My Title")\n');
    });

    test('paragraph with image', () {
      verifyTextInvariant('See ![photo](img.png) here\n');
    });

    test('paragraph with image and title', () {
      verifyTextInvariant('![alt](url "title")\n');
    });

    test('paragraph with autolink', () {
      verifyTextInvariant('Visit <https://example.com> now\n');
    });

    test('fenced code block', () {
      verifyTextInvariant('```dart\nprint("hello");\n```\n');
    });

    test('fenced code block without language', () {
      verifyTextInvariant('```\ncode\n```\n');
    });

    test('fenced code block with multi-line code', () {
      verifyTextInvariant('```\nline1\nline2\n```\n');
    });

    test('blockquote', () {
      verifyTextInvariant('> Hello world\n');
    });

    test('blockquote with inline formatting', () {
      verifyTextInvariant('> **bold** and *italic*\n');
    });

    test('heading without trailing newline', () {
      verifyTextInvariant('# Heading');
    });

    test('bold with underscore delimiter', () {
      verifyTextInvariant('Hello __bold__ world\n');
    });

    test('italic with underscore delimiter', () {
      verifyTextInvariant('Hello _italic_ world\n');
    });

    test('heading with bold content', () {
      verifyTextInvariant('## **Bold Heading**\n');
    });
  });

  group('revealed mode styling', () {
    test('heading prefix uses syntaxDelimiterStyle', () {
      final doc = parse('# Hello\n');
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      // First child should be the "# " prefix with delimiter style
      final children = span.children!.cast<TextSpan>();
      expect(children[0].text, equals('# '));
      expect(children[0].style, equals(theme.syntaxDelimiterStyle));
    });

    test('bold delimiters use syntaxDelimiterStyle', () {
      final doc = parse('**bold**\n');
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      final children = span.children!.cast<TextSpan>();
      // Should have: ** + bold + ** + \n
      expect(children[0].text, equals('**'));
      expect(children[0].style, equals(theme.syntaxDelimiterStyle));
      expect(children[1].text, equals('bold'));
      expect(children[1].style, equals(theme.boldStyle));
      expect(children[2].text, equals('**'));
      expect(children[2].style, equals(theme.syntaxDelimiterStyle));
    });

    test('inline code delimiters use syntaxDelimiterStyle', () {
      final doc = parse('`code`\n');
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      final children = span.children!.cast<TextSpan>();
      expect(children[0].text, equals('`'));
      expect(children[0].style, equals(theme.syntaxDelimiterStyle));
      expect(children[1].text, equals('code'));
      expect(children[1].style, equals(theme.inlineCodeStyle));
      expect(children[2].text, equals('`'));
      expect(children[2].style, equals(theme.syntaxDelimiterStyle));
    });
  });

  group('link styling', () {
    test('revealed link shows brackets and url as delimiters', () {
      final doc = parse('[text](url)\n');
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      final children = span.children!.cast<TextSpan>();
      // [ + text + ](url) + \n
      expect(children[0].text, equals('['));
      expect(children[0].style, equals(theme.syntaxDelimiterStyle));
      expect(children[1].text, equals('text'));
      expect(children[1].style, equals(theme.linkStyle));
      expect(children[2].text, equals('](url)'));
      expect(children[2].style, equals(theme.syntaxDelimiterStyle));
    });

    test('collapsed link hides brackets and url', () {
      final doc = parse('[text](url)\n');
      final span = engine.buildCollapsedSpan(doc.blocks[0], theme.baseStyle);
      final children = span.children!.cast<TextSpan>();
      expect(children[0].text, equals('['));
      expect(children[0].style, equals(theme.hiddenSyntaxStyle));
      expect(children[1].text, equals('text'));
      expect(children[1].style, equals(theme.linkStyle));
      expect(children[2].text, equals('](url)'));
      expect(children[2].style, equals(theme.hiddenSyntaxStyle));
    });
  });

  group('collapsed mode styling', () {
    test('heading prefix uses hiddenSyntaxStyle', () {
      final doc = parse('# Hello\n');
      final span = engine.buildCollapsedSpan(doc.blocks[0], theme.baseStyle);
      final children = span.children!.cast<TextSpan>();
      expect(children[0].text, equals('# '));
      expect(children[0].style, equals(theme.hiddenSyntaxStyle));
    });

    test('bold delimiters use hiddenSyntaxStyle', () {
      final doc = parse('**bold**\n');
      final span = engine.buildCollapsedSpan(doc.blocks[0], theme.baseStyle);
      final children = span.children!.cast<TextSpan>();
      expect(children[0].text, equals('**'));
      expect(children[0].style, equals(theme.hiddenSyntaxStyle));
      expect(children[1].text, equals('bold'));
      expect(children[1].style, equals(theme.boldStyle));
      expect(children[2].text, equals('**'));
      expect(children[2].style, equals(theme.hiddenSyntaxStyle));
    });

    test('heading content uses heading style in collapsed mode', () {
      final doc = parse('## Title\n');
      final span = engine.buildCollapsedSpan(doc.blocks[0], theme.baseStyle);
      final children = span.children!.cast<TextSpan>();
      // children[0] = "## " (hidden), children[1] = "Title" (heading), children[2] = "\n"
      expect(children[1].text, equals('Title'));
      expect(children[1].style, equals(theme.headingStyles[1]));
    });
  });

  group('escaped characters', () {
    test('backslash uses delimiter style, character uses content style', () {
      final doc = parse('\\*\n');
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      final children = span.children!.cast<TextSpan>();
      expect(children[0].text, equals('\\'));
      expect(children[0].style, equals(theme.syntaxDelimiterStyle));
      expect(children[1].text, equals('*'));
      expect(children[1].style, equals(theme.baseStyle));
    });
  });

  group('thematic break', () {
    test('uses delimiter style for entire source', () {
      final doc = parse('---\n');
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      expect(span.text, equals('---\n'));
      expect(span.style, equals(theme.syntaxDelimiterStyle));
    });
  });

  group('blank line', () {
    test('uses base style', () {
      final doc = parse('# Hi\n\n');
      // Second block is a blank line
      final blank = doc.blocks[1];
      final span = engine.buildRevealedSpan(blank, theme.baseStyle);
      expect(span.text, equals('\n'));
      expect(span.style, equals(theme.baseStyle));
    });
  });
}
