import 'package:flutter_test/flutter_test.dart';
import 'package:petitparser/petitparser.dart';

import 'package:markdowner/markdowner.dart';

void main() {
  late MarkdownParserDefinition definition;
  late Parser parser;

  setUp(() {
    definition = MarkdownParserDefinition();
    parser = definition.build();
  });

  /// Parse and return a MarkdownDocument, failing the test if parse fails.
  MarkdownDocument parse(String input) {
    final result = parser.parse(input);
    if (result is Failure) {
      fail('Parse failed at ${result.position}: ${result.message}');
    }
    return (result as Success).value as MarkdownDocument;
  }

  group('empty document', () {
    test('produces empty block list', () {
      final doc = parse('');
      expect(doc.blocks, isEmpty);
    });
  });

  group('blank lines', () {
    test('single blank line', () {
      final doc = parse('\n');
      expect(doc.blocks, hasLength(1));
      expect(doc.blocks[0], isA<BlankLineBlock>());
    });

    test('multiple blank lines', () {
      final doc = parse('\n\n\n');
      expect(doc.blocks, hasLength(3));
      expect(doc.blocks.every((b) => b is BlankLineBlock), isTrue);
    });
  });

  group('ATX headings', () {
    test('h1 with plain text', () {
      final doc = parse('# Hello\n');
      expect(doc.blocks, hasLength(1));
      final h = doc.blocks[0] as HeadingBlock;
      expect(h.level, 1);
      expect(h.delimiter, '#');
      expect(h.children, hasLength(1));
      expect(h.children[0], isA<PlainTextInline>());
      expect((h.children[0] as PlainTextInline).text, 'Hello');
    });

    test('h3 with token offsets', () {
      final doc = parse('### Heading\n');
      final h = doc.blocks[0] as HeadingBlock;
      expect(h.level, 3);
      expect(h.sourceStart, 0);
      expect(h.sourceStop, 12); // '### Heading\n'.length
      expect(h.contentStart, 4); // after '### '
    });

    test('h6', () {
      final doc = parse('###### Deep\n');
      final h = doc.blocks[0] as HeadingBlock;
      expect(h.level, 6);
      expect(h.delimiter, '######');
    });

    test('heading at end of input (no newline)', () {
      final doc = parse('# Title');
      final h = doc.blocks[0] as HeadingBlock;
      expect(h.level, 1);
      expect((h.children[0] as PlainTextInline).text, 'Title');
    });

    test('heading with bold content', () {
      final doc = parse('# Hello **world**\n');
      final h = doc.blocks[0] as HeadingBlock;
      expect(h.children, hasLength(2));
      expect(h.children[0], isA<PlainTextInline>());
      expect((h.children[0] as PlainTextInline).text, 'Hello ');
      expect(h.children[1], isA<BoldInline>());
    });
  });

  group('thematic breaks', () {
    test('--- break', () {
      final doc = parse('---\n');
      expect(doc.blocks, hasLength(1));
      final tb = doc.blocks[0] as ThematicBreakBlock;
      expect(tb.marker, '---');
    });

    test('*** break', () {
      final doc = parse('***\n');
      final tb = doc.blocks[0] as ThematicBreakBlock;
      expect(tb.marker, '***');
    });

    test('___ break', () {
      final doc = parse('___\n');
      final tb = doc.blocks[0] as ThematicBreakBlock;
      expect(tb.marker, '___');
    });

    test('break at end of input', () {
      final doc = parse('---');
      final tb = doc.blocks[0] as ThematicBreakBlock;
      expect(tb.marker, '---');
    });

    test('--- followed by text is NOT a thematic break', () {
      final doc = parse('---text\n');
      // Should be parsed as a paragraph, not a thematic break
      expect(doc.blocks[0], isA<ParagraphBlock>());
    });
  });

  group('paragraphs', () {
    test('plain text paragraph', () {
      final doc = parse('Hello world\n');
      expect(doc.blocks, hasLength(1));
      final p = doc.blocks[0] as ParagraphBlock;
      expect(p.children, hasLength(1));
      expect((p.children[0] as PlainTextInline).text, 'Hello world');
    });

    test('paragraph at end of input', () {
      final doc = parse('Hello world');
      final p = doc.blocks[0] as ParagraphBlock;
      expect((p.children[0] as PlainTextInline).text, 'Hello world');
    });

    test('paragraph token offsets', () {
      final doc = parse('Hello\n');
      final p = doc.blocks[0] as ParagraphBlock;
      expect(p.sourceStart, 0);
      expect(p.sourceStop, 6); // 'Hello\n'.length
    });
  });

  group('bold inline', () {
    test('**bold** in paragraph', () {
      final doc = parse('**bold**\n');
      final p = doc.blocks[0] as ParagraphBlock;
      expect(p.children, hasLength(1));
      final b = p.children[0] as BoldInline;
      expect(b.delimiter, '**');
      expect(b.children, hasLength(1));
      expect((b.children[0] as PlainTextInline).text, 'bold');
    });

    test('__bold__ in paragraph', () {
      final doc = parse('__bold__\n');
      final p = doc.blocks[0] as ParagraphBlock;
      final b = p.children[0] as BoldInline;
      expect(b.delimiter, '__');
      expect((b.children[0] as PlainTextInline).text, 'bold');
    });

    test('bold token offsets', () {
      final doc = parse('x**bold**y\n');
      final p = doc.blocks[0] as ParagraphBlock;
      // children: plain "x", bold, plain "y"
      expect(p.children, hasLength(3));
      final b = p.children[1] as BoldInline;
      expect(b.sourceStart, 1);
      expect(b.sourceStop, 9); // '**bold**' = 8 chars starting at 1
    });
  });

  group('italic inline', () {
    test('*italic* in paragraph', () {
      final doc = parse('*italic*\n');
      final p = doc.blocks[0] as ParagraphBlock;
      final i = p.children[0] as ItalicInline;
      expect(i.delimiter, '*');
      expect((i.children[0] as PlainTextInline).text, 'italic');
    });

    test('_italic_ in paragraph', () {
      final doc = parse('_italic_\n');
      final p = doc.blocks[0] as ParagraphBlock;
      final i = p.children[0] as ItalicInline;
      expect(i.delimiter, '_');
      expect((i.children[0] as PlainTextInline).text, 'italic');
    });
  });

  group('bold-italic inline', () {
    test('***text*** in paragraph', () {
      final doc = parse('***bold italic***\n');
      final p = doc.blocks[0] as ParagraphBlock;
      final bi = p.children[0] as BoldItalicInline;
      expect((bi.children[0] as PlainTextInline).text, 'bold italic');
    });

    test('bold-italic token offsets', () {
      final doc = parse('***abc***\n');
      final p = doc.blocks[0] as ParagraphBlock;
      final bi = p.children[0] as BoldItalicInline;
      expect(bi.sourceStart, 0);
      expect(bi.sourceStop, 9);
      expect(bi.contentStart, 3);
      expect(bi.contentStop, 6);
    });
  });

  group('inline code', () {
    test('`code` in paragraph', () {
      final doc = parse('`code`\n');
      final p = doc.blocks[0] as ParagraphBlock;
      final ic = p.children[0] as InlineCodeInline;
      expect(ic.delimiter, '`');
      expect(ic.code, 'code');
    });

    test('``code with backtick inside``', () {
      final doc = parse('``code ` here``\n');
      final p = doc.blocks[0] as ParagraphBlock;
      final ic = p.children[0] as InlineCodeInline;
      expect(ic.delimiter, '``');
      expect(ic.code, 'code ` here');
    });
  });

  group('strikethrough inline', () {
    test('~~deleted~~ in paragraph', () {
      final doc = parse('~~deleted~~\n');
      final p = doc.blocks[0] as ParagraphBlock;
      final st = p.children[0] as StrikethroughInline;
      expect((st.children[0] as PlainTextInline).text, 'deleted');
    });

    test('strikethrough token offsets', () {
      final doc = parse('~~abc~~\n');
      final p = doc.blocks[0] as ParagraphBlock;
      final st = p.children[0] as StrikethroughInline;
      expect(st.sourceStart, 0);
      expect(st.sourceStop, 7);
      expect(st.contentStart, 2);
      expect(st.contentStop, 5);
    });
  });

  group('escaped characters', () {
    test(r'\* escaped asterisk', () {
      final doc = parse(r'\*' '\n');
      final p = doc.blocks[0] as ParagraphBlock;
      expect(p.children[0], isA<EscapedCharInline>());
      expect((p.children[0] as EscapedCharInline).character, '*');
    });

    test(r'\\ escaped backslash', () {
      final doc = parse(r'\\' '\n');
      final p = doc.blocks[0] as ParagraphBlock;
      expect((p.children[0] as EscapedCharInline).character, r'\');
    });

    test('escaped char prevents bold', () {
      final doc = parse(r'\*\*not bold\*\*' '\n');
      final p = doc.blocks[0] as ParagraphBlock;
      // Should NOT contain BoldInline
      for (final child in p.children) {
        expect(child, isNot(isA<BoldInline>()));
      }
    });
  });

  group('fenced code block', () {
    test('backtick fence with language', () {
      final doc = parse('```dart\nprint("hello");\n```\n');
      expect(doc.blocks, hasLength(1));
      final cb = doc.blocks[0] as FencedCodeBlock;
      expect(cb.fence, '```');
      expect(cb.language, 'dart');
      expect(cb.code, 'print("hello");');
    });

    test('backtick fence without language', () {
      final doc = parse('```\ncode here\n```\n');
      final cb = doc.blocks[0] as FencedCodeBlock;
      expect(cb.fence, '```');
      expect(cb.language, isNull);
      expect(cb.code, 'code here');
    });

    test('tilde fence', () {
      final doc = parse('~~~\ncode\n~~~\n');
      final cb = doc.blocks[0] as FencedCodeBlock;
      expect(cb.fence, '~~~');
      expect(cb.code, 'code');
    });

    test('multi-line code content', () {
      final doc = parse('```\nline1\nline2\nline3\n```\n');
      final cb = doc.blocks[0] as FencedCodeBlock;
      expect(cb.code, 'line1\nline2\nline3');
    });

    test('fenced code block roundtrips', () {
      const source = '```dart\nprint("hello");\n```\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });

    test('empty code block roundtrips', () {
      const source = '```\n\n```\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });

    test('fenced code block has no children', () {
      final doc = parse('```\ncode\n```\n');
      final cb = doc.blocks[0] as FencedCodeBlock;
      expect(cb.children, isEmpty);
    });
  });

  group('autolink inline', () {
    test('<url> produces AutolinkInline', () {
      final doc = parse('<https://example.com>\n');
      final p = doc.blocks[0] as ParagraphBlock;
      expect(p.children, hasLength(1));
      final al = p.children[0] as AutolinkInline;
      expect(al.url, 'https://example.com');
    });

    test('autolink roundtrips', () {
      const source = 'Visit <https://example.com> now\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });
  });

  group('image inline', () {
    test('![alt](url) produces ImageInline', () {
      final doc = parse('![photo](img.png)\n');
      final p = doc.blocks[0] as ParagraphBlock;
      expect(p.children, hasLength(1));
      final img = p.children[0] as ImageInline;
      expect(img.alt, 'photo');
      expect(img.url, 'img.png');
      expect(img.title, isNull);
    });

    test('![alt](url "title") captures title', () {
      final doc = parse('![photo](img.png "A photo")\n');
      final p = doc.blocks[0] as ParagraphBlock;
      final img = p.children[0] as ImageInline;
      expect(img.alt, 'photo');
      expect(img.url, 'img.png');
      expect(img.title, 'A photo');
    });

    test('image roundtrips', () {
      const source = 'See ![photo](img.png) here\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });

    test('image with title roundtrips', () {
      const source = '![alt](url "title")\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });
  });

  group('link inline', () {
    test('[text](url) produces LinkInline', () {
      final doc = parse('[click](https://example.com)\n');
      final p = doc.blocks[0] as ParagraphBlock;
      expect(p.children, hasLength(1));
      final link = p.children[0] as LinkInline;
      expect(link.text, 'click');
      expect(link.url, 'https://example.com');
      expect(link.title, isNull);
    });

    test('[text](url "title") captures title', () {
      final doc = parse('[click](https://example.com "My Title")\n');
      final p = doc.blocks[0] as ParagraphBlock;
      final link = p.children[0] as LinkInline;
      expect(link.text, 'click');
      expect(link.url, 'https://example.com');
      expect(link.title, 'My Title');
    });

    test('link token offsets', () {
      final doc = parse('x[a](b)y\n');
      final p = doc.blocks[0] as ParagraphBlock;
      expect(p.children, hasLength(3));
      final link = p.children[1] as LinkInline;
      expect(link.sourceStart, 1);
      expect(link.sourceStop, 7); // [a](b) = 6 chars starting at 1
    });

    test('link roundtrips', () {
      const source = 'See [here](https://example.com) for details\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });

    test('link with title roundtrips', () {
      const source = '[text](url "title")\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });
  });

  group('inline coalescing', () {
    test('stray special chars coalesce with adjacent text', () {
      // A lone * that can't form italic should become plain text
      final doc = parse('hello * world\n');
      final p = doc.blocks[0] as ParagraphBlock;
      // After coalescing, should be a single PlainTextInline
      expect(p.children, hasLength(1));
      expect((p.children[0] as PlainTextInline).text, 'hello * world');
    });

    test('unclosed bold becomes plain text', () {
      final doc = parse('**unclosed\n');
      final p = doc.blocks[0] as ParagraphBlock;
      // ** can't form bold (no closing), so it's plain text
      expect(p.children, hasLength(1));
      expect(p.children[0], isA<PlainTextInline>());
      expect((p.children[0] as PlainTextInline).text, '**unclosed');
    });
  });

  group('mixed inline content', () {
    test('plain + bold + plain', () {
      final doc = parse('Hello **world** end\n');
      final p = doc.blocks[0] as ParagraphBlock;
      expect(p.children, hasLength(3));
      expect((p.children[0] as PlainTextInline).text, 'Hello ');
      expect(p.children[1], isA<BoldInline>());
      expect((p.children[2] as PlainTextInline).text, ' end');
    });

    test('bold + italic + code', () {
      final doc = parse('**bold** *italic* `code`\n');
      final p = doc.blocks[0] as ParagraphBlock;
      expect(p.children.length, greaterThanOrEqualTo(5));
      expect(p.children[0], isA<BoldInline>());
      expect(p.children[2], isA<ItalicInline>());
      expect(p.children[4], isA<InlineCodeInline>());
    });
  });

  group('multi-block document', () {
    test('heading + blank + paragraph + break', () {
      final doc = parse('# Title\n\nSome text\n---\n');
      expect(doc.blocks, hasLength(4));
      expect(doc.blocks[0], isA<HeadingBlock>());
      expect(doc.blocks[1], isA<BlankLineBlock>());
      expect(doc.blocks[2], isA<ParagraphBlock>());
      expect(doc.blocks[3], isA<ThematicBreakBlock>());
    });

    test('all block types', () {
      final doc = parse('# H1\n\n## H2\n\nText\n---\n***\n___\n');
      expect(doc.blocks[0], isA<HeadingBlock>());
      expect(doc.blocks[1], isA<BlankLineBlock>());
      expect(doc.blocks[2], isA<HeadingBlock>());
      expect(doc.blocks[3], isA<BlankLineBlock>());
      expect(doc.blocks[4], isA<ParagraphBlock>());
      expect(doc.blocks[5], isA<ThematicBreakBlock>());
      expect(doc.blocks[6], isA<ThematicBreakBlock>());
      expect(doc.blocks[7], isA<ThematicBreakBlock>());
    });
  });

  group('token offset accuracy', () {
    test('second block starts after first', () {
      final doc = parse('# A\nB\n');
      final h = doc.blocks[0] as HeadingBlock;
      final p = doc.blocks[1] as ParagraphBlock;
      expect(h.sourceStart, 0);
      expect(h.sourceStop, 4); // '# A\n'
      expect(p.sourceStart, 4);
      expect(p.sourceStop, 6); // 'B\n'
    });

    test('inline token offsets within paragraph', () {
      final doc = parse('ab**cd**ef\n');
      final p = doc.blocks[0] as ParagraphBlock;
      // children: plain "ab", bold "cd", plain "ef"
      final plain1 = p.children[0] as PlainTextInline;
      final bold = p.children[1] as BoldInline;
      final plain2 = p.children[2] as PlainTextInline;

      expect(plain1.sourceStart, 0);
      expect(plain1.sourceStop, 2);
      expect(bold.sourceStart, 2);
      expect(bold.sourceStop, 8);
      expect(plain2.sourceStart, 8);
      expect(plain2.sourceStop, 10);
    });
  });
}
