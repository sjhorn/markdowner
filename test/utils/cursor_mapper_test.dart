import 'package:flutter_test/flutter_test.dart';
import 'package:petitparser/petitparser.dart';

import 'package:markdowner/markdowner.dart';

void main() {
  late Parser parser;

  setUp(() {
    parser = MarkdownParserDefinition().build();
  });

  MarkdownDocument parse(String source) {
    final result = parser.parse(source);
    if (result is Failure) {
      fail('Parse failed at ${result.position}: ${result.message}');
    }
    return (result as Success).value as MarkdownDocument;
  }

  group('delimiterRanges()', () {
    test('plain paragraph has no delimiters', () {
      final doc = parse('Hello world\n');
      final ranges = CursorMapper.delimiterRanges(doc.blocks[0]);
      expect(ranges, isEmpty);
    });

    test('heading has prefix delimiter', () {
      final doc = parse('## Hello\n');
      final ranges = CursorMapper.delimiterRanges(doc.blocks[0]);
      // "## " is 3 chars
      expect(ranges, contains((0, 3)));
    });

    test('bold has open and close delimiters', () {
      final doc = parse('**bold**\n');
      final ranges = CursorMapper.delimiterRanges(doc.blocks[0]);
      expect(ranges, contains((0, 2))); // opening **
      expect(ranges, contains((6, 8))); // closing **
    });

    test('italic with single asterisk', () {
      final doc = parse('*italic*\n');
      final ranges = CursorMapper.delimiterRanges(doc.blocks[0]);
      expect(ranges, contains((0, 1))); // opening *
      expect(ranges, contains((7, 8))); // closing *
    });

    test('bold italic has 3-char delimiters', () {
      final doc = parse('***bi***\n');
      final ranges = CursorMapper.delimiterRanges(doc.blocks[0]);
      expect(ranges, contains((0, 3))); // opening ***
      expect(ranges, contains((5, 8))); // closing ***
    });

    test('inline code has backtick delimiters', () {
      final doc = parse('`code`\n');
      final ranges = CursorMapper.delimiterRanges(doc.blocks[0]);
      expect(ranges, contains((0, 1))); // opening `
      expect(ranges, contains((5, 6))); // closing `
    });

    test('strikethrough has tilde delimiters', () {
      final doc = parse('~~strike~~\n');
      final ranges = CursorMapper.delimiterRanges(doc.blocks[0]);
      expect(ranges, contains((0, 2))); // opening ~~
      expect(ranges, contains((8, 10))); // closing ~~
    });

    test('escaped char has backslash delimiter', () {
      final doc = parse('\\*\n');
      final ranges = CursorMapper.delimiterRanges(doc.blocks[0]);
      expect(ranges, contains((0, 1))); // backslash
    });

    test('thematic break is entirely a delimiter', () {
      final doc = parse('---\n');
      final ranges = CursorMapper.delimiterRanges(doc.blocks[0]);
      expect(ranges, contains((0, 4))); // entire "---\n"
    });

    test('blank line has no delimiters', () {
      final doc = parse('# Hi\n\n');
      final blankBlock = doc.blocks[1];
      final ranges = CursorMapper.delimiterRanges(blankBlock);
      expect(ranges, isEmpty);
    });

    test('link has bracket and url delimiters', () {
      // [text](url)\n
      // 0123456789...
      final doc = parse('[text](url)\n');
      final ranges = CursorMapper.delimiterRanges(doc.blocks[0]);
      expect(ranges, contains((0, 1))); // opening [
      expect(ranges, contains((5, 11))); // ](url)
    });

    test('mixed paragraph has correct ranges', () {
      // "Hello **bold** end\n"
      //  0123456789...
      final doc = parse('Hello **bold** end\n');
      final ranges = CursorMapper.delimiterRanges(doc.blocks[0]);
      expect(ranges, contains((6, 8))); // opening **
      expect(ranges, contains((12, 14))); // closing **
    });
  });

  group('snapToContent()', () {
    test('offset already in content returns same offset', () {
      final doc = parse('**bold**\n');
      // offset 3 is inside "bold" content
      expect(CursorMapper.snapToContent(3, doc.blocks[0]), equals(3));
    });

    test('offset in opening delimiter snaps past it', () {
      final doc = parse('**bold**\n');
      // offset 0 is in "**" opening
      expect(CursorMapper.snapToContent(0, doc.blocks[0]), equals(2));
      expect(CursorMapper.snapToContent(1, doc.blocks[0]), equals(2));
    });

    test('offset in closing delimiter snaps past it', () {
      final doc = parse('**bold**\n');
      // offset 6 is in "**" closing
      expect(CursorMapper.snapToContent(6, doc.blocks[0]), equals(8));
    });

    test('heading prefix snaps to content start', () {
      final doc = parse('## Title\n');
      // "## " is 3 chars
      expect(CursorMapper.snapToContent(0, doc.blocks[0]), equals(3));
      expect(CursorMapper.snapToContent(1, doc.blocks[0]), equals(3));
      expect(CursorMapper.snapToContent(2, doc.blocks[0]), equals(3));
      // offset 3 is content
      expect(CursorMapper.snapToContent(3, doc.blocks[0]), equals(3));
    });

    test('escaped char snaps past backslash', () {
      final doc = parse('\\*\n');
      expect(CursorMapper.snapToContent(0, doc.blocks[0]), equals(1));
    });
  });
}
