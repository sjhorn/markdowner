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
