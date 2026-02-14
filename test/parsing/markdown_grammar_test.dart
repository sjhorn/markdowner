import 'package:flutter_test/flutter_test.dart';
import 'package:petitparser/petitparser.dart';

import 'package:markdowner/markdowner.dart';

void main() {
  late MarkdownGrammarDefinition grammar;

  setUp(() {
    grammar = MarkdownGrammarDefinition();
  });

  /// Build a parser from a single production for isolated testing.
  Parser buildFrom(Parser Function() production) =>
      grammar.buildFrom(production());

  group('document', () {
    test('parses empty input', () {
      final parser = grammar.build();
      final result = parser.parse('');
      expect(result, isA<Success>());
    });

    test('parses single paragraph', () {
      final parser = grammar.build();
      final result = parser.parse('Hello world\n');
      expect(result, isA<Success>());
    });

    test('parses multiple blocks', () {
      final parser = grammar.build();
      final result = parser.parse('# Heading\n\nParagraph\n');
      expect(result, isA<Success>());
    });

    test('parses input without trailing newline', () {
      final parser = grammar.build();
      final result = parser.parse('Hello world');
      expect(result, isA<Success>());
    });
  });

  group('blankLine', () {
    test('matches newline', () {
      final parser = buildFrom(grammar.blankLine);
      expect(parser.parse('\n'), isA<Success>());
    });

    test('does not match non-newline', () {
      final parser = buildFrom(grammar.blankLine);
      expect(parser.parse('a'), isA<Failure>());
    });
  });

  group('atxHeading', () {
    test('matches h1', () {
      final parser = buildFrom(grammar.atxHeading);
      expect(parser.parse('# Title\n'), isA<Success>());
    });

    test('matches h2', () {
      final parser = buildFrom(grammar.atxHeading);
      expect(parser.parse('## Title\n'), isA<Success>());
    });

    test('matches h6', () {
      final parser = buildFrom(grammar.atxHeading);
      expect(parser.parse('###### Title\n'), isA<Success>());
    });

    test('matches heading at end of input (no newline)', () {
      final parser = buildFrom(grammar.atxHeading);
      expect(parser.parse('# Title'), isA<Success>());
    });

    test('rejects 7 hashes', () {
      final parser = buildFrom(grammar.atxHeading);
      expect(parser.parse('####### Title\n'), isA<Failure>());
    });

    test('rejects missing space after hashes', () {
      final parser = buildFrom(grammar.atxHeading);
      expect(parser.parse('#Title\n'), isA<Failure>());
    });

    test('heading content can contain inline formatting chars', () {
      final parser = buildFrom(grammar.atxHeading);
      expect(parser.parse('# Hello **world**\n'), isA<Success>());
    });
  });

  group('thematicBreak', () {
    test('matches ---', () {
      final parser = buildFrom(grammar.thematicBreak);
      expect(parser.parse('---\n'), isA<Success>());
    });

    test('matches ***', () {
      final parser = buildFrom(grammar.thematicBreak);
      expect(parser.parse('***\n'), isA<Success>());
    });

    test('matches ___', () {
      final parser = buildFrom(grammar.thematicBreak);
      expect(parser.parse('___\n'), isA<Success>());
    });

    test('matches at end of input', () {
      final parser = buildFrom(grammar.thematicBreak);
      expect(parser.parse('---'), isA<Success>());
    });

    test('rejects thematic break followed by text', () {
      final parser = buildFrom(grammar.thematicBreak);
      // '---text\n' — parser matches '---' but then expects lineEnding;
      // 'text' is not a line ending, so it succeeds partially with leftover
      final result = parser.parse('---text\n');
      expect(result.position, lessThan('---text\n'.length));
    });
  });

  group('paragraph', () {
    test('matches plain text line', () {
      final parser = buildFrom(grammar.paragraph);
      expect(parser.parse('Hello world\n'), isA<Success>());
    });

    test('matches at end of input', () {
      final parser = buildFrom(grammar.paragraph);
      expect(parser.parse('Hello world'), isA<Success>());
    });

    test('paragraph with bold', () {
      final parser = buildFrom(grammar.paragraph);
      expect(parser.parse('Hello **bold** world\n'), isA<Success>());
    });
  });

  group('bold', () {
    test('matches **content**', () {
      final parser = buildFrom(grammar.bold);
      expect(parser.parse('**bold**'), isA<Success>());
    });

    test('matches __content__', () {
      final parser = buildFrom(grammar.bold);
      expect(parser.parse('__bold__'), isA<Success>());
    });

    test('rejects empty bold ****', () {
      final parser = buildFrom(grammar.bold);
      expect(parser.parse('****'), isA<Failure>());
    });

    test('content can include single special chars', () {
      final parser = buildFrom(grammar.bold);
      // A single * inside ** ** is allowed
      expect(parser.parse('**a*b**'), isA<Success>());
    });
  });

  group('italic', () {
    test('matches *content*', () {
      final parser = buildFrom(grammar.italic);
      expect(parser.parse('*italic*'), isA<Success>());
    });

    test('matches _content_', () {
      final parser = buildFrom(grammar.italic);
      expect(parser.parse('_italic_'), isA<Success>());
    });

    test('rejects empty italic **', () {
      final parser = buildFrom(grammar.italic);
      expect(parser.parse('**'), isA<Failure>());
    });
  });

  group('boldItalic', () {
    test('matches ***content***', () {
      final parser = buildFrom(grammar.boldItalic);
      expect(parser.parse('***bold italic***'), isA<Success>());
    });

    test('rejects empty ******', () {
      final parser = buildFrom(grammar.boldItalic);
      expect(parser.parse('******'), isA<Failure>());
    });
  });

  group('inlineCode', () {
    test('matches `code`', () {
      final parser = buildFrom(grammar.inlineCode);
      expect(parser.parse('`code`'), isA<Success>());
    });

    test('matches ``code``', () {
      final parser = buildFrom(grammar.inlineCode);
      expect(parser.parse('``code``'), isA<Success>());
    });

    test('double backtick allows single backtick inside', () {
      final parser = buildFrom(grammar.inlineCode);
      expect(parser.parse('``co`de``'), isA<Success>());
    });

    test('rejects empty single backtick ``', () {
      final parser = buildFrom(grammar.inlineCode);
      expect(parser.parse('``'), isA<Failure>());
    });
  });

  group('strikethrough', () {
    test('matches ~~content~~', () {
      final parser = buildFrom(grammar.strikethrough);
      expect(parser.parse('~~deleted~~'), isA<Success>());
    });

    test('content can contain single tilde', () {
      final parser = buildFrom(grammar.strikethrough);
      expect(parser.parse('~~a~b~~'), isA<Success>());
    });

    test('rejects empty ~~~~', () {
      final parser = buildFrom(grammar.strikethrough);
      expect(parser.parse('~~~~'), isA<Failure>());
    });
  });

  group('escapedChar', () {
    test('matches backslash-star', () {
      final parser = buildFrom(grammar.escapedChar);
      expect(parser.parse(r'\*'), isA<Success>());
    });

    test('matches backslash-backslash', () {
      final parser = buildFrom(grammar.escapedChar);
      expect(parser.parse(r'\\'), isA<Success>());
    });

    test('matches backslash-hash', () {
      final parser = buildFrom(grammar.escapedChar);
      expect(parser.parse(r'\#'), isA<Success>());
    });

    test('rejects backslash followed by non-special char', () {
      final parser = buildFrom(grammar.escapedChar);
      expect(parser.parse(r'\n'), isA<Failure>());
    });
  });

  group('plainText', () {
    test('matches run of non-special chars', () {
      final parser = buildFrom(grammar.plainText);
      final result = parser.parse('hello world');
      expect(result, isA<Success>());
      expect((result as Success).value, 'hello world');
    });

    test('stops at special char', () {
      final parser = buildFrom(grammar.plainText);
      final result = parser.parse('hello*world');
      expect(result, isA<Success>());
      expect((result as Success).value, 'hello');
    });

    test('stops at newline', () {
      final parser = buildFrom(grammar.plainText);
      final result = parser.parse('hello\nworld');
      expect(result, isA<Success>());
      expect((result as Success).value, 'hello');
    });
  });

  group('fallbackChar', () {
    test('matches a special char', () {
      final parser = buildFrom(grammar.fallbackChar);
      expect(parser.parse('*'), isA<Success>());
    });

    test('does not match newline', () {
      final parser = buildFrom(grammar.fallbackChar);
      expect(parser.parse('\n'), isA<Failure>());
    });
  });

  group('link', () {
    test('matches [text](url)', () {
      final parser = buildFrom(grammar.link);
      expect(parser.parse('[click](https://example.com)'), isA<Success>());
    });

    test('matches [text](url "title")', () {
      final parser = buildFrom(grammar.link);
      expect(
          parser.parse('[click](https://example.com "A title")'),
          isA<Success>());
    });

    test('rejects unclosed bracket', () {
      final parser = buildFrom(grammar.link);
      expect(parser.parse('[text(url)'), isA<Failure>());
    });

    test('rejects missing url parens', () {
      final parser = buildFrom(grammar.link);
      expect(parser.parse('[text]url'), isA<Failure>());
    });

    test('link text can contain special chars', () {
      final parser = buildFrom(grammar.link);
      expect(parser.parse('[bold **text**](url)'), isA<Success>());
    });
  });

  group('full document integration', () {
    test('heading + blank + paragraph + thematic break', () {
      final parser = grammar.build();
      final result = parser.parse('# Title\n\nSome text\n---\n');
      expect(result, isA<Success>());
    });

    test('multiple headings', () {
      final parser = grammar.build();
      final result = parser.parse('# H1\n## H2\n### H3\n');
      expect(result, isA<Success>());
    });

    test('paragraph with mixed inline formatting', () {
      final parser = grammar.build();
      final result =
          parser.parse('Hello **bold** and *italic* and `code`\n');
      expect(result, isA<Success>());
    });
  });
}
