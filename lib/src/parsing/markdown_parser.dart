import 'package:petitparser/petitparser.dart';

import '../core/markdown_nodes.dart';
import 'markdown_grammar.dart';

/// Parser definition that extends [MarkdownGrammarDefinition] with
/// `.token()` and `.map()` transforms to produce AST nodes.
///
/// Usage:
/// ```dart
/// final parser = MarkdownParserDefinition().build();
/// final result = parser.parse(markdownString);
/// if (result.isSuccess) {
///   final doc = result.value as MarkdownDocument;
/// }
/// ```
class MarkdownParserDefinition extends MarkdownGrammarDefinition {
  // ─── Document ───

  @override
  Parser document() => super.document().map((blocks) {
        return MarkdownDocument(blocks: List<MarkdownBlock>.from(blocks));
      });

  // ─── Block Productions ───

  @override
  Parser blankLine() => super.blankLine().token().map((token) {
        return BlankLineBlock(sourceToken: token);
      });

  @override
  Parser atxHeading() => super.atxHeading().token().map((token) {
        final parts = token.value as List;
        final hashes = parts[0] as String;
        final inlines = parts[2] as List;
        return HeadingBlock(
          level: hashes.length,
          delimiter: hashes,
          children: _castInlines(inlines),
          sourceToken: token,
        );
      });

  @override
  Parser table() => super.table().token().map((token) {
        final parts = token.value as List;
        // parts[0] = header row string
        // parts[2] = delimiter row string
        // parts[3] = list of ['\n', bodyRowString] pairs
        final headerStr = parts[0] as String;
        final delimiterStr = parts[2] as String;
        final bodyRowPairs = parts[3] as List;

        final headerCells = _splitRowCells(headerStr);
        final alignments = _parseAlignments(delimiterStr);

        final bodyRows = <TableRow>[];
        for (final pair in bodyRowPairs) {
          final rowStr = (pair as List)[1] as String;
          bodyRows.add(TableRow(cells: _splitRowCells(rowStr)));
        }

        return TableBlock(
          headerRow: TableRow(cells: headerCells),
          delimiterSource: delimiterStr,
          alignments: alignments,
          bodyRows: bodyRows,
          sourceToken: token,
        );
      });

  /// Split a pipe-delimited row string into cells.
  static List<TableCell> _splitRowCells(String row) {
    // Remove leading/trailing pipe and split
    var s = row;
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    return s.split('|').map((c) => TableCell(text: c.trim())).toList();
  }

  /// Parse alignment from delimiter row string like `| :--- | :---: | ---: |`.
  static List<TableAlignment> _parseAlignments(String delimRow) {
    var s = delimRow;
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    return s.split('|').map((cell) {
      final trimmed = cell.trim();
      final leftColon = trimmed.startsWith(':');
      final rightColon = trimmed.endsWith(':');
      if (leftColon && rightColon) return TableAlignment.center;
      if (rightColon) return TableAlignment.right;
      if (leftColon) return TableAlignment.left;
      return TableAlignment.none;
    }).toList();
  }

  @override
  Parser fencedCodeBlock() => super.fencedCodeBlock().token().map((token) {
        final parts = token.value as List;
        final fence = parts[0] as String;
        final infoStr = parts[1] as String?;
        final code = parts[3] as String;
        return FencedCodeBlock(
          fence: fence,
          language: infoStr,
          code: code,
          sourceToken: token,
        );
      });

  @override
  Parser thematicBreak() => super.thematicBreak().token().map((token) {
        final parts = token.value as List;
        final marker = parts[0] as String;
        return ThematicBreakBlock(marker: marker, sourceToken: token);
      });

  @override
  Parser blockquote() => super.blockquote().token().map((token) {
        final parts = token.value as List;
        final inlines = parts[1] as List;
        return BlockquoteBlock(
          children: _castInlines(inlines),
          sourceToken: token,
        );
      });

  @override
  Parser unorderedListItem() =>
      super.unorderedListItem().token().map((token) {
        final parts = token.value as List;
        final indentStr = parts[0] as String?;
        final marker = parts[1] as String;
        final checkboxParts = parts[3] as List?;
        final inlines = parts[4] as List;
        final isTask = checkboxParts != null;
        final taskChecked =
            isTask ? (checkboxParts[0] as String) == '[x]' : null;
        return UnorderedListItemBlock(
          marker: marker,
          indent: indentStr?.length ?? 0,
          isTask: isTask,
          taskChecked: taskChecked,
          children: _castInlines(inlines),
          sourceToken: token,
        );
      });

  @override
  Parser orderedListItem() => super.orderedListItem().token().map((token) {
        final parts = token.value as List;
        final indentStr = parts[0] as String?;
        final numberText = parts[1] as String;
        final punctuation = parts[2] as String;
        final checkboxParts = parts[4] as List?;
        final inlines = parts[5] as List;
        final isTask = checkboxParts != null;
        final taskChecked =
            isTask ? (checkboxParts[0] as String) == '[x]' : null;
        return OrderedListItemBlock(
          number: int.parse(numberText),
          numberText: numberText,
          punctuation: punctuation,
          indent: indentStr?.length ?? 0,
          isTask: isTask,
          taskChecked: taskChecked,
          children: _castInlines(inlines),
          sourceToken: token,
        );
      });

  @override
  Parser setextHeading() => super.setextHeading().token().map((token) {
        final parts = token.value as List;
        final inlines = parts[0] as List;
        final underline = parts[2] as String;
        final level = underline[0] == '=' ? 1 : 2;
        return SetextHeadingBlock(
          level: level,
          underline: underline,
          children: _castInlines(inlines),
          sourceToken: token,
        );
      });

  @override
  Parser paragraph() => super.paragraph().token().map((token) {
        final parts = token.value as List;
        final inlines = parts[0] as List;
        return ParagraphBlock(
          children: _castInlines(inlines),
          sourceToken: token,
        );
      });

  // ─── Inline Content ───

  @override
  Parser inlineContent() => super.inlineContent().map((list) {
        return _coalesceInlines(List<MarkdownInline>.from(list));
      });

  // ─── Inline Productions ───

  @override
  Parser boldItalic() => super.boldItalic().token().map((token) {
        final parts = token.value as List;
        final content = parts[1] as String;
        final contentToken = Token(
          content,
          token.buffer,
          token.start + 3,
          token.stop - 3,
        );
        return BoldItalicInline(
          children: [
            PlainTextInline(text: content, sourceToken: contentToken),
          ],
          sourceToken: token,
        );
      });

  @override
  Parser bold() => super.bold().token().map((token) {
        final parts = token.value as List;
        final delimiter = parts[0] as String;
        final content = parts[1] as String;
        final contentToken = Token(
          content,
          token.buffer,
          token.start + delimiter.length,
          token.stop - delimiter.length,
        );
        return BoldInline(
          delimiter: delimiter,
          children: [
            PlainTextInline(text: content, sourceToken: contentToken),
          ],
          sourceToken: token,
        );
      });

  @override
  Parser italic() => super.italic().token().map((token) {
        final parts = token.value as List;
        final delimiter = parts[0] as String;
        final content = parts[1] as String;
        final contentToken = Token(
          content,
          token.buffer,
          token.start + delimiter.length,
          token.stop - delimiter.length,
        );
        return ItalicInline(
          delimiter: delimiter,
          children: [
            PlainTextInline(text: content, sourceToken: contentToken),
          ],
          sourceToken: token,
        );
      });

  @override
  Parser strikethrough() => super.strikethrough().token().map((token) {
        final parts = token.value as List;
        final content = parts[1] as String;
        final contentToken = Token(
          content,
          token.buffer,
          token.start + 2,
          token.stop - 2,
        );
        return StrikethroughInline(
          children: [
            PlainTextInline(text: content, sourceToken: contentToken),
          ],
          sourceToken: token,
        );
      });

  @override
  Parser inlineCode() => super.inlineCode().token().map((token) {
        final parts = token.value as List;
        final delimiter = parts[0] as String;
        final code = parts[1] as String;
        return InlineCodeInline(
          delimiter: delimiter,
          code: code,
          sourceToken: token,
        );
      });

  @override
  Parser image() => super.image().token().map((token) {
        final parts = token.value as List;
        final alt = parts[1] as String;
        final url = parts[4] as String;
        final titleParts = parts[5] as List?;
        final title = titleParts != null ? titleParts[2] as String : null;
        return ImageInline(
          alt: alt,
          url: url,
          title: title,
          sourceToken: token,
        );
      });

  @override
  Parser link() => super.link().token().map((token) {
        final parts = token.value as List;
        final text = parts[1] as String;
        final url = parts[4] as String;
        final titleParts = parts[5] as List?;
        final title = titleParts != null ? titleParts[2] as String : null;
        return LinkInline(
          text: text,
          url: url,
          title: title,
          sourceToken: token,
        );
      });

  @override
  Parser autolink() => super.autolink().token().map((token) {
        final parts = token.value as List;
        final url = parts[1] as String;
        return AutolinkInline(url: url, sourceToken: token);
      });

  @override
  Parser escapedChar() => super.escapedChar().token().map((token) {
        final parts = token.value as List;
        final character = parts[1] as String;
        return EscapedCharInline(
          character: character,
          sourceToken: token,
        );
      });

  @override
  Parser plainText() => super.plainText().token().map((token) {
        return PlainTextInline(
          text: token.value as String,
          sourceToken: token,
        );
      });

  @override
  Parser fallbackChar() => super.fallbackChar().token().map((token) {
        return PlainTextInline(
          text: token.value as String,
          sourceToken: token,
        );
      });

  // ─── Helpers ───

  /// Cast a raw list (from inlineContent) to typed inline list.
  static List<MarkdownInline> _castInlines(List<dynamic> raw) {
    return List<MarkdownInline>.from(raw);
  }

  /// Merge adjacent [PlainTextInline] nodes into single nodes.
  static List<MarkdownInline> _coalesceInlines(List<MarkdownInline> inlines) {
    if (inlines.length <= 1) return inlines;

    final result = <MarkdownInline>[];
    for (final inline in inlines) {
      if (inline is PlainTextInline &&
          result.isNotEmpty &&
          result.last is PlainTextInline) {
        final prev = result.removeLast() as PlainTextInline;
        final mergedText = prev.text + inline.text;
        final mergedToken = Token(
          mergedText,
          prev.sourceToken.buffer,
          prev.sourceStart,
          inline.sourceStop,
        );
        result.add(PlainTextInline(text: mergedText, sourceToken: mergedToken));
      } else {
        result.add(inline);
      }
    }
    return result;
  }
}
