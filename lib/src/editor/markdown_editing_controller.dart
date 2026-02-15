import 'package:flutter/widgets.dart';
import 'package:petitparser/petitparser.dart' as pp;

import '../core/markdown_nodes.dart';
import '../parsing/markdown_parser.dart';
import '../rendering/markdown_render_engine.dart';
import '../theme/markdown_editor_theme.dart';

/// A [TextEditingController] that parses its text as markdown and builds
/// styled [TextSpan] trees with the reveal/hide WYSIWYG mechanic.
///
/// The block containing the cursor is rendered in "revealed" mode (syntax
/// delimiters visible in muted gray). All other blocks are rendered in
/// "collapsed" mode (delimiters near-invisible).
class MarkdownEditingController extends TextEditingController {
  MarkdownDocument _document = MarkdownDocument(blocks: []);
  final MarkdownRenderEngine _engine;
  final MarkdownEditorTheme _theme;
  late final pp.Parser _parser;

  MarkdownEditingController({
    String? text,
    MarkdownEditorTheme? theme,
  })  : _theme = theme ?? MarkdownEditorTheme.light(),
        _engine = MarkdownRenderEngine(
          theme: theme ?? MarkdownEditorTheme.light(),
        ),
        super(text: text ?? '') {
    _parser = MarkdownParserDefinition().build();
    _reparse();
  }

  /// The current parsed document.
  MarkdownDocument get document => _document;

  /// The theme used for rendering.
  MarkdownEditorTheme get theme => _theme;

  /// The index of the block containing the cursor, or -1.
  int get activeBlockIndex {
    final offset = selection.baseOffset;
    if (offset < 0) return -1;
    return _document.blockIndexAtOffset(offset);
  }

  @override
  set value(TextEditingValue newValue) {
    final textChanged = newValue.text != text;
    super.value = newValue;
    if (textChanged) {
      _reparse();
    }
  }

  void _reparse() {
    if (text.isEmpty) {
      _document = MarkdownDocument(blocks: []);
      return;
    }
    final result = _parser.parse(text);
    if (result is pp.Success) {
      _document = result.value as MarkdownDocument;
    }
    // On parse failure, keep the previous document.
  }

  // ---------------------------------------------------------------------------
  // Inline format toggles
  // ---------------------------------------------------------------------------

  /// Toggle bold (**) around the current selection.
  void toggleBold() => _toggleInlineDelimiter('**');

  /// Toggle italic (*) around the current selection.
  void toggleItalic() => _toggleInlineDelimiter('*');

  /// Toggle inline code (`) around the current selection.
  void toggleInlineCode() => _toggleInlineDelimiter('`');

  /// Toggle strikethrough (~~) around the current selection.
  void toggleStrikethrough() => _toggleInlineDelimiter('~~');

  void _toggleInlineDelimiter(String delimiter) {
    final sel = selection;
    final len = delimiter.length;

    if (sel.isCollapsed) {
      // Insert empty delimiter pair and place cursor between them.
      final offset = sel.baseOffset;
      final newText = text.substring(0, offset) +
          delimiter +
          delimiter +
          text.substring(offset);
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + len),
      );
      return;
    }

    final start = sel.start;
    final end = sel.end;

    // Check if the selection is already wrapped by this delimiter.
    final hasDelimBefore =
        start >= len && text.substring(start - len, start) == delimiter;
    final hasDelimAfter =
        end + len <= text.length && text.substring(end, end + len) == delimiter;

    if (hasDelimBefore && hasDelimAfter) {
      // Unwrap: remove delimiters.
      final newText =
          text.substring(0, start - len) + text.substring(start, end) + text.substring(end + len);
      value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start - len,
          extentOffset: end - len,
        ),
      );
    } else {
      // Wrap: insert delimiters around selection.
      final newText = text.substring(0, start) +
          delimiter +
          text.substring(start, end) +
          delimiter +
          text.substring(end);
      value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start + len,
          extentOffset: end + len,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Heading level
  // ---------------------------------------------------------------------------

  /// Set the heading level (1–6) for the line at the cursor.
  /// Level 0 removes any heading prefix. If the line already has the same
  /// level, the heading is removed (toggle behaviour).
  void setHeadingLevel(int level) {
    assert(level >= 0 && level <= 6);

    final sel = selection;
    final cursorOffset = sel.baseOffset;

    // Find the start of the current line.
    int lineStart = cursorOffset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    // Match existing heading prefix.
    final lineText = text.substring(lineStart);
    final headingMatch = RegExp(r'^(#{1,6}) ').firstMatch(lineText);
    final existingPrefix = headingMatch?.group(0) ?? '';
    final existingLevel =
        headingMatch != null ? headingMatch.group(1)!.length : 0;

    // If toggling to the same level, remove the heading.
    final targetLevel = (level == existingLevel) ? 0 : level;

    final newPrefix = targetLevel > 0 ? '${'#' * targetLevel} ' : '';

    final newText = text.substring(0, lineStart) +
        newPrefix +
        text.substring(lineStart + existingPrefix.length);

    final prefixDelta = newPrefix.length - existingPrefix.length;

    value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: sel.baseOffset + prefixDelta,
        extentOffset: sel.extentOffset + prefixDelta,
      ),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? _theme.baseStyle;

    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final activeIdx = activeBlockIndex;
    final spans = <TextSpan>[];

    for (var i = 0; i < _document.blocks.length; i++) {
      final block = _document.blocks[i];
      if (i == activeIdx) {
        spans.add(_engine.buildRevealedSpan(block, baseStyle));
      } else {
        spans.add(_engine.buildCollapsedSpan(block, baseStyle));
      }
    }

    return TextSpan(children: spans, style: baseStyle);
  }
}
