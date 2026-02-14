import '../core/markdown_nodes.dart';

/// Maps cursor offsets between revealed (raw source) and collapsed (visual)
/// positions within a block.
///
/// In collapsed mode, syntax delimiters are visually hidden but still present
/// in the string. This class helps snap the cursor past hidden delimiters
/// so it doesn't land inside invisible characters.
class CursorMapper {
  /// Returns the ranges of delimiter characters within a block,
  /// expressed as offsets relative to the block's start.
  ///
  /// For example, in `**bold**\n`, the delimiter ranges are
  /// `[(0, 2), (6, 8)]` for the `**` markers.
  static List<(int, int)> delimiterRanges(MarkdownBlock block) {
    final ranges = <(int, int)>[];
    final blockStart = block.sourceStart;

    switch (block) {
      case HeadingBlock():
        // The prefix "## " is a delimiter region
        final prefixLen = block.contentStart - blockStart;
        if (prefixLen > 0) {
          ranges.add((0, prefixLen));
        }
        _addInlineDelimiterRanges(block.children, blockStart, ranges);

      case ParagraphBlock():
        _addInlineDelimiterRanges(block.children, blockStart, ranges);

      case ThematicBreakBlock():
        // Entire source is syntax
        ranges.add((0, block.sourceText.length));

      case BlankLineBlock():
        // No delimiters
        break;

      case BlockquoteBlock():
        // The `> ` prefix (2 chars) is a delimiter
        ranges.add((0, 2));
        _addInlineDelimiterRanges(block.children, blockStart, ranges);

      case FencedCodeBlock():
        final src = block.sourceText;
        final fence = block.fence;
        final infoStr = block.language ?? '';
        final openLineLen = fence.length + infoStr.length + 1; // +1 for \n
        // Open fence line is delimiter
        ranges.add((0, openLineLen));
        // Close fence line: starts after code
        final codeLen = block.code.length;
        final closeStart = openLineLen + codeLen;
        ranges.add((closeStart, src.length));
    }

    return ranges;
  }

  static void _addInlineDelimiterRanges(
    List<MarkdownInline> inlines,
    int blockStart,
    List<(int, int)> ranges,
  ) {
    for (final inline in inlines) {
      switch (inline) {
        case PlainTextInline():
          break; // No delimiters

        case BoldInline():
          final start = inline.sourceStart - blockStart;
          final delimLen = inline.delimiter.length;
          ranges.add((start, start + delimLen));
          ranges.add((
            inline.sourceStop - blockStart - delimLen,
            inline.sourceStop - blockStart,
          ));
          _addInlineDelimiterRanges(inline.children, blockStart, ranges);

        case ItalicInline():
          final start = inline.sourceStart - blockStart;
          final delimLen = inline.delimiter.length;
          ranges.add((start, start + delimLen));
          ranges.add((
            inline.sourceStop - blockStart - delimLen,
            inline.sourceStop - blockStart,
          ));
          _addInlineDelimiterRanges(inline.children, blockStart, ranges);

        case BoldItalicInline():
          final start = inline.sourceStart - blockStart;
          ranges.add((start, start + 3));
          ranges.add((
            inline.sourceStop - blockStart - 3,
            inline.sourceStop - blockStart,
          ));
          _addInlineDelimiterRanges(inline.children, blockStart, ranges);

        case InlineCodeInline():
          final start = inline.sourceStart - blockStart;
          final delimLen = inline.delimiter.length;
          ranges.add((start, start + delimLen));
          ranges.add((
            inline.sourceStop - blockStart - delimLen,
            inline.sourceStop - blockStart,
          ));

        case StrikethroughInline():
          final start = inline.sourceStart - blockStart;
          ranges.add((start, start + 2));
          ranges.add((
            inline.sourceStop - blockStart - 2,
            inline.sourceStop - blockStart,
          ));
          _addInlineDelimiterRanges(inline.children, blockStart, ranges);

        case EscapedCharInline():
          // The backslash is the delimiter
          final start = inline.sourceStart - blockStart;
          ranges.add((start, start + 1));

        case LinkInline():
          final start = inline.sourceStart - blockStart;
          // Opening `[`
          ranges.add((start, start + 1));
          // `](url)` or `](url "title")`
          final suffixStart = start + 1 + inline.text.length;
          final end = inline.sourceStop - blockStart;
          ranges.add((suffixStart, end));

        case ImageInline():
          final start = inline.sourceStart - blockStart;
          // Opening `![`
          ranges.add((start, start + 2));
          // `](url)` or `](url "title")`
          final suffixStart = start + 2 + inline.alt.length;
          final end = inline.sourceStop - blockStart;
          ranges.add((suffixStart, end));

        case AutolinkInline():
          final start = inline.sourceStart - blockStart;
          final end = inline.sourceStop - blockStart;
          // Opening `<`
          ranges.add((start, start + 1));
          // Closing `>`
          ranges.add((end - 1, end));
      }
    }
  }

  /// Snap an offset (relative to block start) past any hidden delimiter
  /// regions. Returns the nearest content offset at or after [offset].
  static int snapToContent(int offset, MarkdownBlock block) {
    final ranges = delimiterRanges(block);
    for (final (start, end) in ranges) {
      if (offset >= start && offset < end) {
        return end;
      }
    }
    return offset;
  }
}
