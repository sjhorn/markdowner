import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/markdowner.dart';
import 'package:petitparser/petitparser.dart';

void main() {
  late MarkdownParserDefinition parserDef;
  late Parser parser;

  setUp(() {
    parserDef = MarkdownParserDefinition();
    parser = parserDef.build();
  });

  MarkdownDocument parse(String source) {
    final result = parser.parse(source);
    if (result is Failure) {
      fail('Parse failed at ${result.position}: ${result.message}');
    }
    return (result as Success).value as MarkdownDocument;
  }

  group('toMarkdown()', () {
    test('roundtrips a simple paragraph', () {
      const source = 'Hello world\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });

    test('roundtrips headings', () {
      const source = '# Heading 1\n## Heading 2\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });

    test('roundtrips mixed blocks', () {
      const source = '# Title\n\nSome **bold** text\n---\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });

    test('roundtrips empty document', () {
      const source = '';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });

    test('roundtrips document with all inline types', () {
      const source = 'plain **bold** *italic* ***bi*** `code` ~~strike~~ \\*esc\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });

    test('roundtrips thematic breaks and blank lines', () {
      const source = '---\n\n***\n\n___\n';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });

    test('roundtrips document without trailing newline', () {
      const source = 'No trailing newline';
      final doc = parse(source);
      expect(doc.toMarkdown(), equals(source));
    });
  });

  group('blockIndexAtOffset()', () {
    test('returns 0 for offset in first block', () {
      const source = '# Heading\nParagraph\n';
      final doc = parse(source);
      expect(doc.blockIndexAtOffset(0), equals(0));
      expect(doc.blockIndexAtOffset(5), equals(0));
    });

    test('returns correct index for second block', () {
      const source = '# Heading\nParagraph\n';
      final doc = parse(source);
      // Second block starts at offset 10
      expect(doc.blockIndexAtOffset(10), equals(1));
      expect(doc.blockIndexAtOffset(15), equals(1));
    });

    test('returns last block index for offset at end', () {
      const source = 'Hello\n';
      final doc = parse(source);
      // offset 6 is at sourceStop of last block
      expect(doc.blockIndexAtOffset(6), equals(0));
    });

    test('returns -1 for negative offset', () {
      const source = 'Hello\n';
      final doc = parse(source);
      expect(doc.blockIndexAtOffset(-1), equals(-1));
    });

    test('returns -1 for offset beyond end', () {
      const source = 'Hello\n';
      final doc = parse(source);
      expect(doc.blockIndexAtOffset(100), equals(-1));
    });

    test('returns -1 for empty document', () {
      final doc = parse('');
      expect(doc.blockIndexAtOffset(0), equals(-1));
    });

    test('handles blank lines between blocks', () {
      const source = '# Heading\n\nParagraph\n';
      final doc = parse(source);
      expect(doc.blocks.length, equals(3));
      // Blank line is index 1
      expect(doc.blockIndexAtOffset(10), equals(1));
      // Paragraph is index 2
      expect(doc.blockIndexAtOffset(11), equals(2));
    });
  });

  group('inlineAtOffset()', () {
    test('returns inline at offset within paragraph', () {
      const source = 'Hello **bold** world\n';
      final doc = parse(source);
      // "Hello " is a PlainTextInline
      final inline0 = doc.inlineAtOffset(0, 0);
      expect(inline0, isA<PlainTextInline>());

      // "**bold**" starts at offset 6
      final inline1 = doc.inlineAtOffset(0, 6);
      expect(inline1, isA<BoldInline>());

      // " world" starts after the bold
      final inline2 = doc.inlineAtOffset(0, 14);
      expect(inline2, isA<PlainTextInline>());
    });

    test('returns null for offset in heading prefix', () {
      const source = '## Heading\n';
      final doc = parse(source);
      // Offset 0 is at the `##` prefix, which is not an inline child
      // The children start at offset 3 (after "## ")
      final inline = doc.inlineAtOffset(0, 0);
      expect(inline, isNull);
    });

    test('returns null for invalid block index', () {
      const source = 'Hello\n';
      final doc = parse(source);
      expect(doc.inlineAtOffset(-1, 0), isNull);
      expect(doc.inlineAtOffset(5, 0), isNull);
    });

    test('returns null for offset past all inlines', () {
      const source = 'Hello\n';
      final doc = parse(source);
      // Offset 5 is the newline which is past the PlainTextInline
      expect(doc.inlineAtOffset(0, 100), isNull);
    });

    test('returns null for blocks with no children', () {
      const source = '---\n';
      final doc = parse(source);
      expect(doc.inlineAtOffset(0, 0), isNull);
    });
  });
}
