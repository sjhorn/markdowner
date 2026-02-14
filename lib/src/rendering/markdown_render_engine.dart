import 'package:flutter/painting.dart';

import '../core/markdown_nodes.dart';
import '../theme/markdown_editor_theme.dart';

/// Builds [TextSpan] trees from parsed markdown blocks.
///
/// Two modes:
/// - **Revealed** (cursor inside block): delimiters styled as muted gray.
/// - **Collapsed** (cursor outside): delimiters styled as near-invisible.
///
/// Critical invariant: the concatenation of all text in the returned TextSpan
/// tree must exactly equal [block.sourceText].
class MarkdownRenderEngine {
  final MarkdownEditorTheme theme;

  MarkdownRenderEngine({required this.theme});

  /// Build a TextSpan for [block] with syntax delimiters visible (muted).
  TextSpan buildRevealedSpan(MarkdownBlock block, TextStyle baseStyle) {
    return _buildBlockSpan(block, baseStyle, revealed: true);
  }

  /// Build a TextSpan for [block] with syntax delimiters near-invisible.
  TextSpan buildCollapsedSpan(MarkdownBlock block, TextStyle baseStyle) {
    return _buildBlockSpan(block, baseStyle, revealed: false);
  }

  TextSpan _buildBlockSpan(
    MarkdownBlock block,
    TextStyle baseStyle, {
    required bool revealed,
  }) {
    final delimiterStyle =
        revealed ? theme.syntaxDelimiterStyle : theme.hiddenSyntaxStyle;

    switch (block) {
      case HeadingBlock():
        return _buildHeadingSpan(block, baseStyle, delimiterStyle, revealed);
      case ParagraphBlock():
        return _buildParagraphSpan(block, baseStyle, delimiterStyle, revealed);
      case ThematicBreakBlock():
        return TextSpan(text: block.sourceText, style: delimiterStyle);
      case BlankLineBlock():
        return TextSpan(text: block.sourceText, style: baseStyle);
    }
  }

  TextSpan _buildHeadingSpan(
    HeadingBlock block,
    TextStyle baseStyle,
    TextStyle delimiterStyle,
    bool revealed,
  ) {
    final headingStyle = theme.headingStyles[block.level - 1];
    // Prefix: "## " (delimiter + space)
    final prefix = block.sourceText.substring(0, block.contentStart - block.sourceStart);
    // Content: inline children
    final inlineSpans = _buildInlineSpanList(
      block.children,
      headingStyle,
      delimiterStyle,
      revealed,
    );
    // Suffix: trailing newline (if present)
    final contentEnd = block.children.isEmpty
        ? block.contentStart - block.sourceStart
        : block.children.last.sourceStop - block.sourceStart;
    final suffix = block.sourceText.substring(contentEnd);

    final children = <TextSpan>[
      TextSpan(text: prefix, style: delimiterStyle),
      ...inlineSpans,
      if (suffix.isNotEmpty) TextSpan(text: suffix, style: headingStyle),
    ];

    return TextSpan(children: children);
  }

  TextSpan _buildParagraphSpan(
    ParagraphBlock block,
    TextStyle baseStyle,
    TextStyle delimiterStyle,
    bool revealed,
  ) {
    final inlineSpans = _buildInlineSpanList(
      block.children,
      baseStyle,
      delimiterStyle,
      revealed,
    );
    // Trailing newline after last inline
    final contentEnd = block.children.isEmpty
        ? 0
        : block.children.last.sourceStop - block.sourceStart;
    final suffix = block.sourceText.substring(contentEnd);

    final children = <TextSpan>[
      ...inlineSpans,
      if (suffix.isNotEmpty) TextSpan(text: suffix, style: baseStyle),
    ];

    return TextSpan(children: children);
  }

  List<TextSpan> _buildInlineSpanList(
    List<MarkdownInline> inlines,
    TextStyle contentStyle,
    TextStyle delimiterStyle,
    bool revealed,
  ) {
    return inlines
        .expand((inline) => _buildInlineSpans(
              inline,
              contentStyle,
              delimiterStyle,
              revealed,
            ))
        .toList();
  }

  /// Produces one or more TextSpan entries for a single inline node.
  List<TextSpan> _buildInlineSpans(
    MarkdownInline inline,
    TextStyle contentStyle,
    TextStyle delimiterStyle,
    bool revealed,
  ) {
    switch (inline) {
      case PlainTextInline():
        return [TextSpan(text: inline.text, style: contentStyle)];

      case BoldInline():
        return _buildFormattedInline(
          sourceText: inline.sourceText,
          delimiterLength: inline.delimiter.length,
          formatStyle: theme.boldStyle,
          delimiterStyle: delimiterStyle,
          children: inline.children,
          revealed: revealed,
        );

      case ItalicInline():
        return _buildFormattedInline(
          sourceText: inline.sourceText,
          delimiterLength: inline.delimiter.length,
          formatStyle: theme.italicStyle,
          delimiterStyle: delimiterStyle,
          children: inline.children,
          revealed: revealed,
        );

      case BoldItalicInline():
        return _buildFormattedInline(
          sourceText: inline.sourceText,
          delimiterLength: 3,
          formatStyle: theme.boldItalicStyle,
          delimiterStyle: delimiterStyle,
          children: inline.children,
          revealed: revealed,
        );

      case InlineCodeInline():
        final delimLen = inline.delimiter.length;
        final openDelim = inline.sourceText.substring(0, delimLen);
        final code = inline.code;
        final closeDelim =
            inline.sourceText.substring(delimLen + code.length);
        return [
          TextSpan(text: openDelim, style: delimiterStyle),
          TextSpan(text: code, style: theme.inlineCodeStyle),
          TextSpan(text: closeDelim, style: delimiterStyle),
        ];

      case StrikethroughInline():
        return _buildFormattedInline(
          sourceText: inline.sourceText,
          delimiterLength: 2,
          formatStyle: theme.strikethroughStyle,
          delimiterStyle: delimiterStyle,
          children: inline.children,
          revealed: revealed,
        );

      case EscapedCharInline():
        // Backslash is delimiter, character is content
        return [
          TextSpan(text: '\\', style: delimiterStyle),
          TextSpan(text: inline.character, style: contentStyle),
        ];

      case LinkInline():
        return _buildLinkSpans(inline, delimiterStyle);

      case ImageInline():
        return _buildImageSpans(inline, delimiterStyle, contentStyle);
    }
  }

  /// Build spans for an image: collapsed shows alt text, hides `![` and `](url)`.
  List<TextSpan> _buildImageSpans(
    ImageInline inline,
    TextStyle delimiterStyle,
    TextStyle contentStyle,
  ) {
    // Source: ![alt](url) or ![alt](url "title")
    final src = inline.sourceText;
    final altEnd = 2 + inline.alt.length; // after ![alt
    final suffix = src.substring(altEnd); // ](url) or ](url "title")
    return [
      TextSpan(text: '![', style: delimiterStyle),
      TextSpan(text: inline.alt, style: contentStyle),
      TextSpan(text: suffix, style: delimiterStyle),
    ];
  }

  /// Build spans for a link: collapsed hides `[`, `](url)`, shows text styled.
  List<TextSpan> _buildLinkSpans(
    LinkInline inline,
    TextStyle delimiterStyle,
  ) {
    // Source: [text](url) or [text](url "title")
    final src = inline.sourceText;
    final textEnd = 1 + inline.text.length; // after [text
    final suffix = src.substring(textEnd); // ](url) or ](url "title")
    return [
      TextSpan(text: '[', style: delimiterStyle),
      TextSpan(text: inline.text, style: theme.linkStyle),
      TextSpan(text: suffix, style: delimiterStyle),
    ];
  }

  /// Helper to build open-delimiter + content + close-delimiter spans.
  List<TextSpan> _buildFormattedInline({
    required String sourceText,
    required int delimiterLength,
    required TextStyle formatStyle,
    required TextStyle delimiterStyle,
    required List<MarkdownInline> children,
    required bool revealed,
  }) {
    final openDelim = sourceText.substring(0, delimiterLength);
    final closeDelim = sourceText.substring(sourceText.length - delimiterLength);
    final contentSpans = _buildInlineSpanList(
      children,
      formatStyle,
      delimiterStyle,
      revealed,
    );
    return [
      TextSpan(text: openDelim, style: delimiterStyle),
      ...contentSpans,
      TextSpan(text: closeDelim, style: delimiterStyle),
    ];
  }
}
