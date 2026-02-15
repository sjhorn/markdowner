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
  // Indent / Outdent
  // ---------------------------------------------------------------------------

  /// Indent the current line. For list items, adds 2-space prefix.
  /// For non-list context, inserts 2 spaces at cursor.
  void indent() {
    final sel = selection;
    final cursorOffset = sel.baseOffset;

    // Find the start and end of the current line.
    int lineStart = cursorOffset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    int lineEnd = cursorOffset;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    final lineText = text.substring(lineStart, lineEnd);

    // Check if line is a list item (unordered or ordered).
    final ulMatch = _unorderedListRe.firstMatch(lineText);
    final olMatch = _orderedListRe.firstMatch(lineText);

    if (ulMatch != null || olMatch != null) {
      // Insert 2 spaces at line start.
      final newText =
          '${text.substring(0, lineStart)}  ${text.substring(lineStart)}';
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorOffset + 2),
      );
    } else {
      // Non-list: insert 2 spaces at cursor.
      final newText = '${text.substring(0, cursorOffset)}  ${text.substring(cursorOffset)}';
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorOffset + 2),
      );
    }
  }

  /// Outdent the current line. For list items, removes 2-space prefix.
  /// No-op for non-list context or list items with no indent.
  void outdent() {
    final sel = selection;
    final cursorOffset = sel.baseOffset;

    // Find the start and end of the current line.
    int lineStart = cursorOffset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    int lineEnd = cursorOffset;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    final lineText = text.substring(lineStart, lineEnd);

    // Check if line is a list item.
    final ulMatch = _unorderedListRe.firstMatch(lineText);
    final olMatch = _orderedListRe.firstMatch(lineText);

    if (ulMatch != null || olMatch != null) {
      final indent =
          ulMatch != null ? ulMatch.group(1)! : olMatch!.group(1)!;
      if (indent.length < 2) return; // No indent to remove.

      // Remove 2 spaces from the beginning of the line.
      final newText =
          text.substring(0, lineStart) + text.substring(lineStart + 2);
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorOffset - 2),
      );
    }
    // Non-list: no-op.
  }

  // ---------------------------------------------------------------------------
  // Insert Link
  // ---------------------------------------------------------------------------

  /// Insert a markdown link at the cursor position.
  ///
  /// - Collapsed cursor: inserts `[](url)` with cursor inside `[]`.
  /// - With selection: wraps as `[selection](url)` with cursor selecting
  ///   `url` inside `()`.
  void insertLink() {
    final sel = selection;

    if (sel.isCollapsed) {
      final offset = sel.baseOffset;
      final newText =
          '${text.substring(0, offset)}[](url)${text.substring(offset)}';
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + 1),
      );
    } else {
      final start = sel.start;
      final end = sel.end;
      final selectedText = text.substring(start, end);
      final newText = '${text.substring(0, start)}[$selectedText](url)${text.substring(end)}';
      final urlStart = start + selectedText.length + 3; // [text](
      value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: urlStart,
          extentOffset: urlStart + 3, // select "url"
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Toggle Code Block
  // ---------------------------------------------------------------------------

  /// Toggle a fenced code block around the current line or selection.
  ///
  /// - If cursor is inside a code block (detected by ``` fences), removes them.
  /// - Otherwise wraps the current line(s) in ``` fences.
  void toggleCodeBlock() {
    final sel = selection;
    final cursorOffset = sel.baseOffset;

    // Find the start of the current line.
    int lineStart = cursorOffset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    // Check if we're inside a code block by looking for ``` fence above and below.
    int? openFenceLineStart;
    int? closeFenceLineEnd;

    // Search backwards for opening ```.
    int searchPos = lineStart;
    while (searchPos > 0) {
      // Move to previous line start.
      int prevLineStart = searchPos - 1;
      while (prevLineStart > 0 && text[prevLineStart - 1] != '\n') {
        prevLineStart--;
      }
      final prevLine = text.substring(prevLineStart, searchPos - 1);
      if (prevLine.startsWith('```')) {
        openFenceLineStart = prevLineStart;
        break;
      }
      searchPos = prevLineStart;
    }

    int? closeFenceLineStart;

    if (openFenceLineStart != null) {
      // Search forwards for closing ```.
      int endLineStart = lineStart;
      // Move past current line.
      int pos = endLineStart;
      while (pos < text.length && text[pos] != '\n') {
        pos++;
      }
      if (pos < text.length) pos++; // skip \n

      while (pos < text.length) {
        int nextLineEnd = pos;
        while (nextLineEnd < text.length && text[nextLineEnd] != '\n') {
          nextLineEnd++;
        }
        final nextLine = text.substring(pos, nextLineEnd);
        if (nextLine.startsWith('```')) {
          closeFenceLineStart = pos;
          closeFenceLineEnd =
              nextLineEnd < text.length ? nextLineEnd + 1 : nextLineEnd;
          break;
        }
        pos = nextLineEnd < text.length ? nextLineEnd + 1 : nextLineEnd;
      }
    }

    if (openFenceLineStart != null && closeFenceLineEnd != null) {
      // Unwrap: remove the fences.
      // Content is between opening fence line end and closing fence line start.
      int openFenceEnd = openFenceLineStart;
      while (openFenceEnd < text.length && text[openFenceEnd] != '\n') {
        openFenceEnd++;
      }
      openFenceEnd++; // skip \n after opening fence

      final content = text.substring(openFenceEnd, closeFenceLineStart!);
      final newText = text.substring(0, openFenceLineStart) +
          content +
          text.substring(closeFenceLineEnd);

      // Adjust cursor: offset by removing the opening fence line.
      final fenceLineLen = openFenceEnd - openFenceLineStart;
      final newCursor = cursorOffset - fenceLineLen;

      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newCursor.clamp(0, newText.length),
        ),
      );
    } else {
      // Wrap: find the line range to wrap.
      int wrapStart = lineStart;
      int wrapEnd;

      if (!sel.isCollapsed) {
        // Multi-line selection: find end of last selected line.
        wrapEnd = sel.end;
        while (wrapEnd < text.length && text[wrapEnd] != '\n') {
          wrapEnd++;
        }
        if (wrapEnd < text.length) wrapEnd++; // include trailing \n
      } else {
        // Single line: find end of current line.
        wrapEnd = lineStart;
        while (wrapEnd < text.length && text[wrapEnd] != '\n') {
          wrapEnd++;
        }
        if (wrapEnd < text.length) wrapEnd++; // include trailing \n
      }

      final content = text.substring(wrapStart, wrapEnd);
      final newText = '${text.substring(0, wrapStart)}```\n$content```\n${text.substring(wrapEnd)}';

      // Cursor moves by 4 (```\n).
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorOffset + 4),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Smart Pair Completion
  // ---------------------------------------------------------------------------

  /// Apply smart pair completion to a text input change.
  ///
  /// Returns a transformed [TextEditingValue] if a pair was auto-completed,
  /// or `null` to indicate pass-through.
  TextEditingValue? applySmartPairCompletion(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only handle single character insertions.
    if (newValue.text.length != oldValue.text.length + 1) return null;
    if (!newValue.selection.isCollapsed) return null;

    final insertPos = newValue.selection.baseOffset - 1;
    if (insertPos < 0) return null;

    final char = newValue.text[insertPos];

    // Don't auto-close inside code blocks or inline code.
    if (_isInsideCodeContext(oldValue.text, oldValue.selection.baseOffset)) {
      return null;
    }

    // Backtick: auto-close to `` with cursor between.
    if (char == '`') {
      final text = newValue.text;
      final newText = '${text.substring(0, insertPos + 1)}`${text.substring(insertPos + 1)}';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: insertPos + 1),
      );
    }

    // Bracket: auto-close to [](url) with cursor inside [].
    if (char == '[') {
      final text = newValue.text;
      // Check if preceded by ! for image syntax.
      if (insertPos > 0 && text[insertPos - 1] == '!') {
        // Image: ![](url)
        final newText = '${text.substring(0, insertPos + 1)}](url)${text.substring(insertPos + 1)}';
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: insertPos + 1),
        );
      }
      // Link: [](url)
      final newText = '${text.substring(0, insertPos + 1)}](url)${text.substring(insertPos + 1)}';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: insertPos + 1),
      );
    }

    // Double-delimiter pairs: ** and ~~
    if (char == '*' && insertPos > 0 && newValue.text[insertPos - 1] == '*') {
      // Just typed **, auto-close to ****
      final text = newValue.text;
      final newText = '${text.substring(0, insertPos + 1)}**${text.substring(insertPos + 1)}';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: insertPos + 1),
      );
    }

    if (char == '~' && insertPos > 0 && newValue.text[insertPos - 1] == '~') {
      // Just typed ~~, auto-close to ~~~~
      final text = newValue.text;
      final newText = '${text.substring(0, insertPos + 1)}~~${text.substring(insertPos + 1)}';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: insertPos + 1),
      );
    }

    return null;
  }

  /// Check if the cursor is inside a code context (inline code or code block).
  bool _isInsideCodeContext(String text, int offset) {
    // Check for code block: look for ``` before offset without a matching
    // closing ``` before offset.
    int codeBlockFences = 0;
    int searchPos = 0;
    while (searchPos < offset) {
      // Find next line start.
      int lineStart = searchPos;
      int lineEnd = text.indexOf('\n', searchPos);
      if (lineEnd == -1) lineEnd = text.length;

      final line = text.substring(lineStart, lineEnd);
      if (line.startsWith('```')) {
        codeBlockFences++;
      }

      searchPos = lineEnd + 1;
      if (searchPos > text.length) break;
    }
    // Odd number of fences means we're inside a code block.
    if (codeBlockFences.isOdd) return true;

    // Check for inline code: count unescaped backticks before offset on
    // the current line.
    int lineStart = offset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    int backtickCount = 0;
    for (int i = lineStart; i < offset; i++) {
      if (text[i] == '`') backtickCount++;
    }
    // Odd backtick count means we're inside inline code.
    return backtickCount.isOdd;
  }

  // ---------------------------------------------------------------------------
  // Smart Enter
  // ---------------------------------------------------------------------------

  /// Line-level patterns for list items, blockquotes, and headings.
  static final _unorderedListRe =
      RegExp(r'^(\s*)([-*+]) (\[[ x]\] )?(.*)$');
  static final _orderedListRe =
      RegExp(r'^(\s*)(\d+)([.)]) (\[[ x]\] )?(.*)$');
  static final _blockquoteRe = RegExp(r'^> (.*)$');
  static final _headingRe = RegExp(r'^(#{1,6}) (.*)$');

  /// Apply smart Enter behaviour to a text input change.
  ///
  /// Returns a transformed [TextEditingValue] if the Enter was handled,
  /// or `null` to indicate pass-through (default behaviour).
  ///
  /// [oldValue] is the value before the platform inserted `\n`.
  /// [newValue] is the value after the platform inserted `\n`.
  TextEditingValue? applySmartEnter(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only handle collapsed cursors (no selection replacement).
    if (!oldValue.selection.isCollapsed) return null;

    final cursorPos = oldValue.selection.baseOffset;
    final text = oldValue.text;

    // Find the start of the current line.
    int lineStart = cursorPos;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final lineText = text.substring(lineStart, cursorPos);

    // Try unordered / task list.
    final ulMatch = _unorderedListRe.firstMatch(lineText);
    if (ulMatch != null) {
      final indent = ulMatch.group(1)!;
      final marker = ulMatch.group(2)!;
      final taskPart = ulMatch.group(3); // e.g. "[ ] " or "[x] " or null
      final content = ulMatch.group(4)!;

      if (content.isEmpty && (taskPart == null || taskPart.isEmpty)) {
        // Empty list item — exit: remove marker, leave blank line.
        return _exitPrefix(text, lineStart, cursorPos);
      }
      if (content.isEmpty && taskPart != null && taskPart.isNotEmpty) {
        // Empty task item — exit.
        return _exitPrefix(text, lineStart, cursorPos);
      }

      // Continuation: split at cursor within content.
      final afterCursor = text.substring(cursorPos);

      // New prefix always gets "[ ] " for tasks (unchecked).
      final newTaskPart = taskPart != null ? '[ ] ' : '';
      final newPrefix = '$indent$marker $newTaskPart';

      final before = text.substring(0, cursorPos);
      final newText = '$before\n$newPrefix$afterCursor';
      final newCursorPos = cursorPos + 1 + newPrefix.length;

      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPos),
      );
    }

    // Try ordered / task list.
    final olMatch = _orderedListRe.firstMatch(lineText);
    if (olMatch != null) {
      final indent = olMatch.group(1)!;
      final num = int.parse(olMatch.group(2)!);
      final punct = olMatch.group(3)!; // "." or ")"
      final taskPart = olMatch.group(4); // e.g. "[ ] " or null
      final content = olMatch.group(5)!;

      if (content.isEmpty && (taskPart == null || taskPart.isEmpty)) {
        return _exitPrefix(text, lineStart, cursorPos);
      }
      if (content.isEmpty && taskPart != null && taskPart.isNotEmpty) {
        return _exitPrefix(text, lineStart, cursorPos);
      }

      final newTaskPart = taskPart != null ? '[ ] ' : '';
      final newPrefix = '$indent${num + 1}$punct $newTaskPart';

      final before = text.substring(0, cursorPos);
      final afterCursor = text.substring(cursorPos);
      final newText = '$before\n$newPrefix$afterCursor';
      final newCursorPos = cursorPos + 1 + newPrefix.length;

      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPos),
      );
    }

    // Try blockquote.
    final bqMatch = _blockquoteRe.firstMatch(lineText);
    if (bqMatch != null) {
      final content = bqMatch.group(1)!;

      if (content.isEmpty) {
        return _exitPrefix(text, lineStart, cursorPos);
      }

      final before = text.substring(0, cursorPos);
      final afterCursor = text.substring(cursorPos);
      final newText = '$before\n> $afterCursor';
      final newCursorPos = cursorPos + 1 + 2; // \n + "> "

      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPos),
      );
    }

    // Try heading — insert \n but don't continue the prefix.
    final hMatch = _headingRe.firstMatch(lineText);
    if (hMatch != null) {
      final before = text.substring(0, cursorPos);
      final afterCursor = text.substring(cursorPos);
      final newText = '$before\n$afterCursor';
      final newCursorPos = cursorPos + 1;

      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPos),
      );
    }

    // No special context — pass through.
    return null;
  }

  /// Remove the prefix on the current line, leaving cursor on a blank line.
  TextEditingValue _exitPrefix(String text, int lineStart, int cursorPos) {
    // Remove everything from lineStart to cursorPos (the prefix).
    final before = text.substring(0, lineStart);
    final after = text.substring(cursorPos);
    final newText = '$before$after';

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lineStart),
    );
  }

  // ---------------------------------------------------------------------------
  // Smart Backspace
  // ---------------------------------------------------------------------------

  /// Apply smart Backspace behaviour to a text input change.
  ///
  /// Returns a transformed [TextEditingValue] if the Backspace was handled,
  /// or `null` to indicate pass-through (default behaviour).
  TextEditingValue? applySmartBackspace(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only handle collapsed cursors.
    if (!oldValue.selection.isCollapsed) return null;

    final cursorPos = oldValue.selection.baseOffset;
    final text = oldValue.text;
    if (cursorPos <= 0) return null;

    // Find the start of the current line.
    int lineStart = cursorPos;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final lineText = text.substring(lineStart);

    // Determine the content start offset for recognized prefixes.
    int? contentStart;

    final ulMatch = _unorderedListRe.firstMatch(lineText);
    if (ulMatch != null) {
      // prefix = indent + marker + " " + optional task part
      contentStart = lineStart + ulMatch.group(1)!.length +
          ulMatch.group(2)!.length + 1 +
          (ulMatch.group(3)?.length ?? 0);
    }

    final olMatch = _orderedListRe.firstMatch(lineText);
    if (contentStart == null && olMatch != null) {
      contentStart = lineStart + olMatch.group(1)!.length +
          olMatch.group(2)!.length + olMatch.group(3)!.length + 1 +
          (olMatch.group(4)?.length ?? 0);
    }

    if (contentStart == null) {
      final bqMatch = _blockquoteRe.firstMatch(lineText);
      if (bqMatch != null) {
        contentStart = lineStart + 2; // "> "
      }
    }

    if (contentStart == null) {
      final hMatch = _headingRe.firstMatch(lineText);
      if (hMatch != null) {
        contentStart = lineStart + hMatch.group(1)!.length + 1; // "## "
      }
    }

    // Only trigger if cursor is exactly at the content start.
    if (contentStart == null || cursorPos != contentStart) return null;

    // Remove the entire prefix, keep content.
    final before = text.substring(0, lineStart);
    final content = text.substring(contentStart);
    final newText = '$before$content';

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lineStart),
    );
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
