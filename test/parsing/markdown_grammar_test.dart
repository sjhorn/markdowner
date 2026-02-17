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

  group('table', () {
    test('matches simple table', () {
      final parser = grammar.build();
      const input = '| A | B |\n| --- | --- |';
      final result = parser.parse(input);
      expect(result, isA<Success>());
    });

    test('matches table with body rows', () {
      final parser = grammar.build();
      const input = '| A | B |\n| --- | --- |\n| 1 | 2 |';
      final result = parser.parse(input);
      expect(result, isA<Success>());
    });

    test('matches table with alignment', () {
      final parser = grammar.build();
      const input = '| Left | Center | Right |\n| :--- | :---: | ---: |';
      final result = parser.parse(input);
      expect(result, isA<Success>());
    });
  });

  group('setextHeading', () {
    test('matches content with = underline', () {
      final parser = buildFrom(grammar.setextHeading);
      expect(parser.parse('Title\n===\n'), isA<Success>());
    });

    test('matches content with - underline', () {
      final parser = buildFrom(grammar.setextHeading);
      expect(parser.parse('Title\n---\n'), isA<Success>());
    });

    test('matches multiple = chars', () {
      final parser = buildFrom(grammar.setextHeading);
      expect(parser.parse('Title\n======\n'), isA<Success>());
    });

    test('underline at end of input', () {
      final parser = buildFrom(grammar.setextHeading);
      expect(parser.parse('Title\n==='), isA<Success>());
    });

    test('content can have inline formatting', () {
      final parser = buildFrom(grammar.setextHeading);
      expect(parser.parse('**Bold** title\n===\n'), isA<Success>());
    });
  });

  group('orderedListItem', () {
    test('matches 1. item', () {
      final parser = buildFrom(grammar.orderedListItem);
      expect(parser.parse('1. item\n'), isA<Success>());
    });

    test('matches 2) item', () {
      final parser = buildFrom(grammar.orderedListItem);
      expect(parser.parse('2) item\n'), isA<Success>());
    });

    test('matches multi-digit number', () {
      final parser = buildFrom(grammar.orderedListItem);
      expect(parser.parse('10. tenth\n'), isA<Success>());
    });

    test('matches with task checkbox', () {
      final parser = buildFrom(grammar.orderedListItem);
      expect(parser.parse('1. [x] done\n'), isA<Success>());
    });

    test('matches with indent', () {
      final parser = buildFrom(grammar.orderedListItem);
      expect(parser.parse('  1. nested\n'), isA<Success>());
    });

    test('rejects missing space', () {
      final parser = buildFrom(grammar.orderedListItem);
      expect(parser.parse('1.item\n'), isA<Failure>());
    });
  });

  group('unorderedListItem', () {
    test('matches - item', () {
      final parser = buildFrom(grammar.unorderedListItem);
      expect(parser.parse('- item\n'), isA<Success>());
    });

    test('matches * item', () {
      final parser = buildFrom(grammar.unorderedListItem);
      expect(parser.parse('* item\n'), isA<Success>());
    });

    test('matches + item', () {
      final parser = buildFrom(grammar.unorderedListItem);
      expect(parser.parse('+ item\n'), isA<Success>());
    });

    test('matches with task checkbox [x]', () {
      final parser = buildFrom(grammar.unorderedListItem);
      expect(parser.parse('- [x] done\n'), isA<Success>());
    });

    test('matches with task checkbox [ ]', () {
      final parser = buildFrom(grammar.unorderedListItem);
      expect(parser.parse('- [ ] todo\n'), isA<Success>());
    });

    test('matches with indent', () {
      final parser = buildFrom(grammar.unorderedListItem);
      expect(parser.parse('  - nested\n'), isA<Success>());
    });

    test('rejects missing space after marker', () {
      final parser = buildFrom(grammar.unorderedListItem);
      expect(parser.parse('-item\n'), isA<Failure>());
    });
  });

  group('blockquote', () {
    test('matches > content', () {
      final parser = buildFrom(grammar.blockquote);
      expect(parser.parse('> Hello world\n'), isA<Success>());
    });

    test('matches at end of input', () {
      final parser = buildFrom(grammar.blockquote);
      expect(parser.parse('> Hello'), isA<Success>());
    });

    test('rejects missing space after >', () {
      final parser = buildFrom(grammar.blockquote);
      expect(parser.parse('>Hello\n'), isA<Failure>());
    });

    test('content can have inline formatting', () {
      final parser = buildFrom(grammar.blockquote);
      expect(parser.parse('> **bold** text\n'), isA<Success>());
    });
  });

  group('fencedCodeBlock', () {
    test('matches backtick fence with language', () {
      final parser = grammar.build();
      final result = parser.parse('```dart\nprint("hello");\n```\n');
      expect(result, isA<Success>());
    });

    test('matches tilde fence', () {
      final parser = grammar.build();
      final result = parser.parse('~~~\ncode\n~~~\n');
      expect(result, isA<Success>());
    });

    test('matches fence without language', () {
      final parser = grammar.build();
      final result = parser.parse('```\ncode\n```\n');
      expect(result, isA<Success>());
    });

    test('matches multi-line code content', () {
      final parser = grammar.build();
      final result = parser.parse('```\nline1\nline2\nline3\n```\n');
      expect(result, isA<Success>());
    });
  });

  group('autolink', () {
    test('matches <url>', () {
      final parser = buildFrom(grammar.autolink);
      expect(parser.parse('<https://example.com>'), isA<Success>());
    });

    test('rejects unclosed angle bracket', () {
      final parser = buildFrom(grammar.autolink);
      expect(parser.parse('<https://example.com'), isA<Failure>());
    });

    test('rejects empty angle brackets', () {
      final parser = buildFrom(grammar.autolink);
      expect(parser.parse('<>'), isA<Failure>());
    });
  });

  group('image', () {
    test('matches ![alt](url)', () {
      final parser = buildFrom(grammar.image);
      expect(parser.parse('![photo](img.png)'), isA<Success>());
    });

    test('matches ![alt](url "title")', () {
      final parser = buildFrom(grammar.image);
      expect(parser.parse('![photo](img.png "A photo")'), isA<Success>());
    });

    test('rejects missing !', () {
      final parser = buildFrom(grammar.image);
      expect(parser.parse('[alt](url)'), isA<Failure>());
    });

    test('rejects empty alt', () {
      final parser = buildFrom(grammar.image);
      expect(parser.parse('![](url)'), isA<Failure>());
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

  group('highlight', () {
    test('matches ==text==', () {
      final parser = buildFrom(grammar.highlight);
      expect(parser.parse('==highlighted=='), isA<Success>());
    });

    test('rejects =text= (single equals)', () {
      final parser = buildFrom(grammar.highlight);
      expect(parser.parse('=text='), isA<Failure>());
    });

    test('rejects empty ====', () {
      final parser = buildFrom(grammar.highlight);
      expect(parser.parse('===='), isA<Failure>());
    });

    test('content can include single =', () {
      final parser = buildFrom(grammar.highlight);
      expect(parser.parse('==a=b=='), isA<Success>());
    });
  });

  group('subscript', () {
    test('matches ~text~', () {
      final parser = buildFrom(grammar.subscript);
      expect(parser.parse('~sub~'), isA<Success>());
    });

    test('does NOT match ~~text~~ (strikethrough)', () {
      final parser = buildFrom(grammar.subscript);
      final result = parser.parse('~~text~~');
      // subscript only matches single ~, so ~~text~~ should not fully match
      if (result is Success) {
        // If it matched, it should not have consumed the whole string
        expect(result.position, lessThan('~~text~~'.length));
      }
    });

    test('rejects content with ~ inside', () {
      final parser = buildFrom(grammar.subscript);
      expect(parser.parse('~a~b~'), isA<Success>());
      final result = parser.parse('~a~b~') as Success;
      // Should match ~a~ (stops at first ~)
      expect(result.position, 3);
    });
  });

  group('superscript', () {
    test('matches ^text^', () {
      final parser = buildFrom(grammar.superscript);
      expect(parser.parse('^sup^'), isA<Success>());
    });

    test('rejects empty ^^', () {
      final parser = buildFrom(grammar.superscript);
      expect(parser.parse('^^'), isA<Failure>());
    });

    test('content stops at ^', () {
      final parser = buildFrom(grammar.superscript);
      final result = parser.parse('^a^b^') as Success;
      expect(result.position, 3);
    });
  });

  group('extension config', () {
    test('disabled highlight parses as plain text', () {
      final disabledGrammar = MarkdownGrammarDefinition(
        enabledExtensions: {
          MarkdownExtension.subscript,
          MarkdownExtension.superscript,
        },
      );
      final parser = disabledGrammar.build();
      final result = parser.parse('==highlighted==\n');
      expect(result, isA<Success>());
      // It should succeed (parsed as plain text), but the highlight
      // production itself should fail
      final highlightParser =
          disabledGrammar.buildFrom(disabledGrammar.highlight());
      expect(highlightParser.parse('==highlighted=='), isA<Failure>());
    });

    test('disabled subscript parses as plain text', () {
      final disabledGrammar = MarkdownGrammarDefinition(
        enabledExtensions: {
          MarkdownExtension.highlight,
          MarkdownExtension.superscript,
        },
      );
      final subscriptParser =
          disabledGrammar.buildFrom(disabledGrammar.subscript());
      expect(subscriptParser.parse('~sub~'), isA<Failure>());
    });

    test('disabled superscript parses as plain text', () {
      final disabledGrammar = MarkdownGrammarDefinition(
        enabledExtensions: {
          MarkdownExtension.highlight,
          MarkdownExtension.subscript,
        },
      );
      final superscriptParser =
          disabledGrammar.buildFrom(disabledGrammar.superscript());
      expect(superscriptParser.parse('^sup^'), isA<Failure>());
    });

    test('all extensions enabled by default', () {
      // Default grammar should parse all three
      final parser = grammar.build();
      expect(parser.parse('==hi== ~sub~ ^sup^\n'), isA<Success>());
    });
  });
}
