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
