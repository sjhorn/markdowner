import 'package:petitparser/petitparser.dart';

/// Base class for all markdown AST nodes.
///
/// Every node carries a PetitParser [Token] that records its exact position
/// in the source string:
/// - [Token.start] — offset of first character (inclusive)
/// - [Token.stop] — offset past last character (exclusive)
/// - [Token.input] — the raw source substring
sealed class MarkdownNode {
  final Token sourceToken;

  MarkdownNode({required this.sourceToken});

  /// Offset of the first character of this node in the source string.
  int get sourceStart => sourceToken.start;

  /// Offset past the last character of this node in the source string.
  int get sourceStop => sourceToken.stop;

  /// The raw source text of this node (including all syntax characters).
  String get sourceText => sourceToken.input;
}

/// Base class for block-level AST nodes.
sealed class MarkdownBlock extends MarkdownNode {
  MarkdownBlock({required super.sourceToken});

  /// The inline children of this block (if applicable).
  List<MarkdownInline> get children;
}

/// Base class for inline-level AST nodes.
sealed class MarkdownInline extends MarkdownNode {
  MarkdownInline({required super.sourceToken});
}

// ─── Document ───

/// Top-level container: a parsed markdown document is a list of blocks.
class MarkdownDocument {
  final List<MarkdownBlock> blocks;

  MarkdownDocument({required this.blocks});

  /// Lossless roundtrip: reconstruct the original markdown source from blocks.
  String toMarkdown() => blocks.map((b) => b.sourceText).join();

  /// Returns the index of the block that contains [offset], or -1 if none.
  ///
  /// [offset] is a character offset into the full source string.
  int blockIndexAtOffset(int offset) {
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (offset >= block.sourceStart && offset < block.sourceStop) {
        return i;
      }
    }
    // Allow cursor at end of last block (e.g. at sourceStop of last block).
    if (blocks.isNotEmpty && offset == blocks.last.sourceStop) {
      return blocks.length - 1;
    }
    return -1;
  }

  /// Returns the inline node at [offset] within the block at [blockIndex],
  /// or `null` if the offset is outside any inline (e.g. in the heading prefix).
  MarkdownInline? inlineAtOffset(int blockIndex, int offset) {
    if (blockIndex < 0 || blockIndex >= blocks.length) return null;
    final block = blocks[blockIndex];
    for (final inline in block.children) {
      if (offset >= inline.sourceStart && offset < inline.sourceStop) {
        return inline;
      }
    }
    return null;
  }
}

// ─── Block Nodes (Phase 1) ───

/// ATX heading: `# Heading` through `###### Heading`.
class HeadingBlock extends MarkdownBlock {
  final int level;
  final String delimiter;
  @override
  final List<MarkdownInline> children;

  HeadingBlock({
    required this.level,
    required this.delimiter,
    required this.children,
    required super.sourceToken,
  });

  /// Offset where the content text starts (after `# `).
  int get contentStart => sourceStart + delimiter.length + 1;
}

/// A paragraph: one or more lines of inline content.
class ParagraphBlock extends MarkdownBlock {
  @override
  final List<MarkdownInline> children;

  ParagraphBlock({required this.children, required super.sourceToken});
}

/// A thematic break: `---`, `***`, or `___`.
class ThematicBreakBlock extends MarkdownBlock {
  final String marker;

  @override
  List<MarkdownInline> get children => const [];

  ThematicBreakBlock({required this.marker, required super.sourceToken});
}

/// A blank line.
class BlankLineBlock extends MarkdownBlock {
  @override
  List<MarkdownInline> get children => const [];

  BlankLineBlock({required super.sourceToken});
}

// ─── Block Nodes (Phase 2) ───

/// A fenced code block: ``` or ~~~, with optional language info string.
class FencedCodeBlock extends MarkdownBlock {
  final String fence;
  final String? language;
  final String code;

  @override
  List<MarkdownInline> get children => const [];

  FencedCodeBlock({
    required this.fence,
    this.language,
    required this.code,
    required super.sourceToken,
  });
}

/// A blockquote line: `> content`.
class BlockquoteBlock extends MarkdownBlock {
  @override
  final List<MarkdownInline> children;

  BlockquoteBlock({required this.children, required super.sourceToken});

  /// Offset where content starts (after `> `).
  int get contentStart => sourceStart + 2;
}

/// An unordered list item: `- item`, `* item`, `+ item`, with optional task checkbox.
class UnorderedListItemBlock extends MarkdownBlock {
  final String marker;
  final int indent;
  final bool isTask;
  final bool? taskChecked;
  @override
  final List<MarkdownInline> children;

  UnorderedListItemBlock({
    required this.marker,
    this.indent = 0,
    this.isTask = false,
    this.taskChecked,
    required this.children,
    required super.sourceToken,
  });

  /// Length of the prefix before content: indent + marker + space + optional checkbox.
  int get prefixLength =>
      indent + 1 + 1 + (isTask ? 4 : 0); // marker(1) + space(1) + "[x] "(4)

  /// Offset where content starts.
  int get contentStart => sourceStart + prefixLength;
}

/// An ordered list item: `1. item`, `2) item`, with optional task checkbox.
class OrderedListItemBlock extends MarkdownBlock {
  final int number;
  final String numberText;
  final String punctuation;
  final int indent;
  final bool isTask;
  final bool? taskChecked;
  @override
  final List<MarkdownInline> children;

  OrderedListItemBlock({
    required this.number,
    required this.numberText,
    required this.punctuation,
    this.indent = 0,
    this.isTask = false,
    this.taskChecked,
    required this.children,
    required super.sourceToken,
  });

  /// Length of the prefix before content: indent + numberText + punctuation + space + optional checkbox.
  int get prefixLength =>
      indent + numberText.length + 1 + 1 + (isTask ? 4 : 0); // punct(1) + space(1)

  /// Offset where content starts.
  int get contentStart => sourceStart + prefixLength;
}

/// A setext heading: content line + underline (`===` or `---`).
class SetextHeadingBlock extends MarkdownBlock {
  final int level;
  final String underline;
  @override
  final List<MarkdownInline> children;

  SetextHeadingBlock({
    required this.level,
    required this.underline,
    required this.children,
    required super.sourceToken,
  });
}

/// Column alignment in a GFM table.
enum TableAlignment { left, center, right, none }

/// A single cell in a table row.
class TableCell {
  final String text;

  TableCell({required this.text});
}

/// A single row in a table.
class TableRow {
  final List<TableCell> cells;

  TableRow({required this.cells});
}

/// A GFM table block.
class TableBlock extends MarkdownBlock {
  final TableRow headerRow;
  final String delimiterSource;
  final List<TableAlignment> alignments;
  final List<TableRow> bodyRows;

  @override
  List<MarkdownInline> get children => const [];

  TableBlock({
    required this.headerRow,
    required this.delimiterSource,
    required this.alignments,
    required this.bodyRows,
    required super.sourceToken,
  });
}

// ─── Inline Nodes (Phase 1) ───

/// Plain text with no formatting.
class PlainTextInline extends MarkdownInline {
  final String text;

  PlainTextInline({required this.text, required super.sourceToken});
}

/// Bold text: `**bold**` or `__bold__`.
class BoldInline extends MarkdownInline {
  final String delimiter;
  final List<MarkdownInline> children;

  BoldInline({
    required this.delimiter,
    required this.children,
    required super.sourceToken,
  });

  int get contentStart => sourceStart + delimiter.length;
  int get contentStop => sourceStop - delimiter.length;
}

/// Italic text: `*italic*` or `_italic_`.
class ItalicInline extends MarkdownInline {
  final String delimiter;
  final List<MarkdownInline> children;

  ItalicInline({
    required this.delimiter,
    required this.children,
    required super.sourceToken,
  });

  int get contentStart => sourceStart + delimiter.length;
  int get contentStop => sourceStop - delimiter.length;
}

/// Bold-italic text: `***bold italic***`.
class BoldItalicInline extends MarkdownInline {
  final List<MarkdownInline> children;

  BoldItalicInline({required this.children, required super.sourceToken});

  int get contentStart => sourceStart + 3;
  int get contentStop => sourceStop - 3;
}

/// Inline code: `` `code` `` or ``` ``code`` ```.
class InlineCodeInline extends MarkdownInline {
  final String delimiter;
  final String code;

  InlineCodeInline({
    required this.delimiter,
    required this.code,
    required super.sourceToken,
  });

  int get contentStart => sourceStart + delimiter.length;
  int get contentStop => sourceStop - delimiter.length;
}

/// Strikethrough text: `~~deleted~~`.
class StrikethroughInline extends MarkdownInline {
  final List<MarkdownInline> children;

  StrikethroughInline({required this.children, required super.sourceToken});

  int get contentStart => sourceStart + 2;
  int get contentStop => sourceStop - 2;
}

/// An escaped character: `\*`, `\#`, etc.
class EscapedCharInline extends MarkdownInline {
  final String character;

  EscapedCharInline({required this.character, required super.sourceToken});
}

// ─── Inline Nodes (Phase 2) ───

/// A link: `[text](url)` or `[text](url "title")`.
class LinkInline extends MarkdownInline {
  final String text;
  final String url;
  final String? title;

  LinkInline({
    required this.text,
    required this.url,
    this.title,
    required super.sourceToken,
  });
}

/// An image: `![alt](url)` or `![alt](url "title")`.
class ImageInline extends MarkdownInline {
  final String alt;
  final String url;
  final String? title;

  ImageInline({
    required this.alt,
    required this.url,
    this.title,
    required super.sourceToken,
  });
}

/// An autolink: `<url>`.
class AutolinkInline extends MarkdownInline {
  final String url;

  AutolinkInline({required this.url, required super.sourceToken});
}
