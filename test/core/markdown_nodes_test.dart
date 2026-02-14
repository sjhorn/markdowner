import 'package:flutter_test/flutter_test.dart';
import 'package:petitparser/petitparser.dart';

import 'package:markdowner/markdowner.dart';

/// Helper to create a Token for testing.
Token<T> _tok<T>(T value, String buffer, int start, int stop) =>
    Token(value, buffer, start, stop);

void main() {
  group('MarkdownDocument', () {
    test('holds a list of blocks', () {
      final doc = MarkdownDocument(blocks: []);
      expect(doc.blocks, isEmpty);
    });
  });

  group('MarkdownNode base', () {
    test('sourceStart, sourceStop, sourceText from Token', () {
      const src = '# Hello\n';
      final token = _tok(['#', ' ', 'Hello'], src, 0, 8);
      final heading = HeadingBlock(
        level: 1,
        delimiter: '#',
        children: [],
        sourceToken: token,
      );
      expect(heading.sourceStart, 0);
      expect(heading.sourceStop, 8);
      expect(heading.sourceText, '# Hello\n');
    });
  });

  group('HeadingBlock', () {
    test('level and delimiter are stored', () {
      const src = '## Title\n';
      final token = _tok(null, src, 0, 9);
      final heading = HeadingBlock(
        level: 2,
        delimiter: '##',
        children: [],
        sourceToken: token,
      );
      expect(heading.level, 2);
      expect(heading.delimiter, '##');
      expect(heading.children, isEmpty);
    });

    test('contentStart accounts for delimiter and space', () {
      const src = '### Heading\n';
      final token = _tok(null, src, 0, 12);
      final heading = HeadingBlock(
        level: 3,
        delimiter: '###',
        children: [],
        sourceToken: token,
      );
      // '### ' = 4 chars, so content starts at offset 4
      expect(heading.contentStart, 4);
    });
  });

  group('ParagraphBlock', () {
    test('holds inline children', () {
      const src = 'Hello world\n';
      final token = _tok(null, src, 0, 12);
      final para = ParagraphBlock(children: [], sourceToken: token);
      expect(para.children, isEmpty);
      expect(para.sourceText, src);
    });
  });

  group('ThematicBreakBlock', () {
    test('stores marker', () {
      const src = '---\n';
      final token = _tok(null, src, 0, 4);
      final tb = ThematicBreakBlock(marker: '---', sourceToken: token);
      expect(tb.marker, '---');
      expect(tb.children, isEmpty);
    });
  });

  group('BlankLineBlock', () {
    test('has no children', () {
      final token = _tok(null, '\n', 0, 1);
      final blank = BlankLineBlock(sourceToken: token);
      expect(blank.children, isEmpty);
    });
  });

  group('PlainTextInline', () {
    test('stores text', () {
      const src = 'hello';
      final token = _tok(src, src, 0, 5);
      final pt = PlainTextInline(text: 'hello', sourceToken: token);
      expect(pt.text, 'hello');
    });
  });

  group('BoldInline', () {
    test('contentStart and contentStop', () {
      const src = '**bold**';
      final token = _tok(null, src, 0, 8);
      final bold = BoldInline(
        delimiter: '**',
        children: [],
        sourceToken: token,
      );
      expect(bold.contentStart, 2);
      expect(bold.contentStop, 6);
    });

    test('underscore delimiter', () {
      const src = '__bold__';
      final token = _tok(null, src, 0, 8);
      final bold = BoldInline(
        delimiter: '__',
        children: [],
        sourceToken: token,
      );
      expect(bold.contentStart, 2);
      expect(bold.contentStop, 6);
    });
  });

  group('ItalicInline', () {
    test('contentStart and contentStop', () {
      const src = '*italic*';
      final token = _tok(null, src, 0, 8);
      final italic = ItalicInline(
        delimiter: '*',
        children: [],
        sourceToken: token,
      );
      expect(italic.contentStart, 1);
      expect(italic.contentStop, 7);
    });
  });

  group('BoldItalicInline', () {
    test('contentStart and contentStop', () {
      const src = '***text***';
      final token = _tok(null, src, 0, 10);
      final bi = BoldItalicInline(children: [], sourceToken: token);
      expect(bi.contentStart, 3);
      expect(bi.contentStop, 7);
    });
  });

  group('InlineCodeInline', () {
    test('stores code and delimiter', () {
      const src = '`code`';
      final token = _tok(null, src, 0, 6);
      final ic = InlineCodeInline(
        delimiter: '`',
        code: 'code',
        sourceToken: token,
      );
      expect(ic.delimiter, '`');
      expect(ic.code, 'code');
      expect(ic.contentStart, 1);
      expect(ic.contentStop, 5);
    });
  });

  group('StrikethroughInline', () {
    test('contentStart and contentStop', () {
      const src = '~~deleted~~';
      final token = _tok(null, src, 0, 11);
      final st = StrikethroughInline(children: [], sourceToken: token);
      expect(st.contentStart, 2);
      expect(st.contentStop, 9);
    });
  });

  group('EscapedCharInline', () {
    test('stores the escaped character', () {
      const src = r'\*';
      final token = _tok(null, src, 0, 2);
      final ec = EscapedCharInline(character: '*', sourceToken: token);
      expect(ec.character, '*');
    });
  });

  group('LinkInline', () {
    test('stores text, url, and optional title', () {
      const src = '[text](url "title")';
      final token = _tok(null, src, 0, 19);
      final link = LinkInline(
        text: 'text',
        url: 'url',
        title: 'title',
        sourceToken: token,
      );
      expect(link.text, 'text');
      expect(link.url, 'url');
      expect(link.title, 'title');
    });

    test('title can be null', () {
      const src = '[text](url)';
      final token = _tok(null, src, 0, 11);
      final link = LinkInline(
        text: 'text',
        url: 'url',
        sourceToken: token,
      );
      expect(link.title, isNull);
    });
  });

  group('TableBlock', () {
    test('stores header, alignments, body rows', () {
      const src = '| A | B |\n| --- | --- |';
      final token = _tok(null, src, 0, src.length);
      final table = TableBlock(
        headerRow: TableRow(cells: [
          TableCell(text: 'A'),
          TableCell(text: 'B'),
        ]),
        delimiterSource: '| --- | --- |',
        alignments: [TableAlignment.none, TableAlignment.none],
        bodyRows: [],
        sourceToken: token,
      );
      expect(table.headerRow.cells, hasLength(2));
      expect(table.alignments, hasLength(2));
      expect(table.bodyRows, isEmpty);
      expect(table.children, isEmpty);
    });
  });

  group('SetextHeadingBlock', () {
    test('stores level, underline, children', () {
      const src = 'Title\n===\n';
      final token = _tok(null, src, 0, 10);
      final sh = SetextHeadingBlock(
        level: 1,
        underline: '===',
        children: [],
        sourceToken: token,
      );
      expect(sh.level, 1);
      expect(sh.underline, '===');
      expect(sh.children, isEmpty);
    });
  });

  group('OrderedListItemBlock', () {
    test('stores number, punctuation and children', () {
      const src = '1. item\n';
      final token = _tok(null, src, 0, 8);
      final li = OrderedListItemBlock(
        number: 1,
        numberText: '1',
        punctuation: '.',
        children: [],
        sourceToken: token,
      );
      expect(li.number, 1);
      expect(li.numberText, '1');
      expect(li.punctuation, '.');
      expect(li.prefixLength, 3); // "1. "
      expect(li.contentStart, 3);
    });

    test('multi-digit number prefix', () {
      const src = '10. item\n';
      final token = _tok(null, src, 0, 9);
      final li = OrderedListItemBlock(
        number: 10,
        numberText: '10',
        punctuation: '.',
        children: [],
        sourceToken: token,
      );
      expect(li.prefixLength, 4); // "10. "
    });

    test('task checkbox adds to prefix', () {
      const src = '1. [x] done\n';
      final token = _tok(null, src, 0, 12);
      final li = OrderedListItemBlock(
        number: 1,
        numberText: '1',
        punctuation: '.',
        isTask: true,
        taskChecked: true,
        children: [],
        sourceToken: token,
      );
      expect(li.prefixLength, 7); // "1. [x] "
    });
  });

  group('UnorderedListItemBlock', () {
    test('stores marker and children', () {
      const src = '- item\n';
      final token = _tok(null, src, 0, 7);
      final li = UnorderedListItemBlock(
        marker: '-',
        children: [],
        sourceToken: token,
      );
      expect(li.marker, '-');
      expect(li.prefixLength, 2); // "- "
      expect(li.contentStart, 2);
    });

    test('task checkbox adds to prefix', () {
      const src = '- [x] done\n';
      final token = _tok(null, src, 0, 11);
      final li = UnorderedListItemBlock(
        marker: '-',
        isTask: true,
        taskChecked: true,
        children: [],
        sourceToken: token,
      );
      expect(li.prefixLength, 6); // "- [x] "
      expect(li.contentStart, 6);
    });

    test('indent is accounted for', () {
      const src = '  - item\n';
      final token = _tok(null, src, 0, 9);
      final li = UnorderedListItemBlock(
        marker: '-',
        indent: 2,
        children: [],
        sourceToken: token,
      );
      expect(li.prefixLength, 4); // "  - "
      expect(li.contentStart, 4);
    });
  });

  group('BlockquoteBlock', () {
    test('stores children and contentStart', () {
      const src = '> Hello\n';
      final token = _tok(null, src, 0, 8);
      final bq = BlockquoteBlock(children: [], sourceToken: token);
      expect(bq.contentStart, 2);
      expect(bq.children, isEmpty);
    });
  });

  group('FencedCodeBlock', () {
    test('stores fence, language, and code', () {
      const src = '```dart\ncode\n```\n';
      final token = _tok(null, src, 0, 17);
      final cb = FencedCodeBlock(
        fence: '```',
        language: 'dart',
        code: 'code',
        sourceToken: token,
      );
      expect(cb.fence, '```');
      expect(cb.language, 'dart');
      expect(cb.code, 'code');
      expect(cb.children, isEmpty);
    });

    test('language can be null', () {
      const src = '```\ncode\n```\n';
      final token = _tok(null, src, 0, 13);
      final cb = FencedCodeBlock(
        fence: '```',
        code: 'code',
        sourceToken: token,
      );
      expect(cb.language, isNull);
    });
  });

  group('AutolinkInline', () {
    test('stores url', () {
      const src = '<https://example.com>';
      final token = _tok(null, src, 0, 21);
      final al = AutolinkInline(url: 'https://example.com', sourceToken: token);
      expect(al.url, 'https://example.com');
    });
  });

  group('ImageInline', () {
    test('stores alt, url, and optional title', () {
      const src = '![alt](url "title")';
      final token = _tok(null, src, 0, 19);
      final img = ImageInline(
        alt: 'alt',
        url: 'url',
        title: 'title',
        sourceToken: token,
      );
      expect(img.alt, 'alt');
      expect(img.url, 'url');
      expect(img.title, 'title');
    });

    test('title can be null', () {
      const src = '![alt](url)';
      final token = _tok(null, src, 0, 11);
      final img = ImageInline(
        alt: 'alt',
        url: 'url',
        sourceToken: token,
      );
      expect(img.title, isNull);
    });
  });

  group('sealed class hierarchy', () {
    test('MarkdownBlock subtypes are MarkdownNode', () {
      final token = _tok(null, '\n', 0, 1);
      final blank = BlankLineBlock(sourceToken: token);
      expect(blank, isA<MarkdownNode>());
      expect(blank, isA<MarkdownBlock>());
    });

    test('MarkdownInline subtypes are MarkdownNode', () {
      final token = _tok('hi', 'hi', 0, 2);
      final pt = PlainTextInline(text: 'hi', sourceToken: token);
      expect(pt, isA<MarkdownNode>());
      expect(pt, isA<MarkdownInline>());
    });
  });
}
