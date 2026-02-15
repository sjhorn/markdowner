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
        return _buildThematicBreakSpan(block, delimiterStyle, revealed);
      case BlankLineBlock():
        return TextSpan(text: block.sourceText, style: baseStyle);
      case FencedCodeBlock():
        return _buildFencedCodeSpan(block, delimiterStyle, revealed);
      case BlockquoteBlock():
        return _buildBlockquoteSpan(block, delimiterStyle, revealed);
      case UnorderedListItemBlock():
        return _buildTaskAwareListItemSpan(
            block, block.prefixLength, block.children, baseStyle, delimiterStyle, revealed,
            isTask: block.isTask, taskChecked: block.taskChecked);
      case OrderedListItemBlock():
        return _buildTaskAwareListItemSpan(
            block, block.prefixLength, block.children, baseStyle, delimiterStyle, revealed,
            isTask: block.isTask, taskChecked: block.taskChecked);
      case SetextHeadingBlock():
        return _buildSetextHeadingSpan(block, baseStyle, delimiterStyle, revealed);
      case TableBlock():
        // Phase 2: show full source in monospace; WidgetSpan rendering is Phase 4
        return TextSpan(text: block.sourceText, style: theme.codeBlockStyle);
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

      case AutolinkInline():
        return [
          TextSpan(text: '<', style: delimiterStyle),
          TextSpan(text: inline.url, style: theme.linkStyle),
          TextSpan(text: '>', style: delimiterStyle),
        ];
    }
  }

  TextSpan _buildSetextHeadingSpan(
    SetextHeadingBlock block,
    TextStyle baseStyle,
    TextStyle delimiterStyle,
    bool revealed,
  ) {
    final headingStyle = theme.headingStyles[block.level - 1];
    final src = block.sourceText;
    // Content is everything up to the newline before underline
    final contentEnd = block.children.isEmpty
        ? 0
        : block.children.last.sourceStop - block.sourceStart;
    final suffix = src.substring(contentEnd); // \nunderline\n

    final inlineSpans = _buildInlineSpanList(
      block.children,
      headingStyle,
      delimiterStyle,
      revealed,
    );

    return TextSpan(
      children: [
        ...inlineSpans,
        TextSpan(text: suffix, style: delimiterStyle),
      ],
    );
  }

  TextSpan _buildThematicBreakSpan(
    ThematicBreakBlock block,
    TextStyle delimiterStyle,
    bool revealed,
  ) {
    if (revealed) {
      return TextSpan(text: block.sourceText, style: delimiterStyle);
    }
    // Collapsed mode: split marker text from trailing newline for styling.
    final src = block.sourceText;
    final markerEnd = src.indexOf('\n');
    if (markerEnd < 0) {
      return TextSpan(text: src, style: theme.thematicBreakStyle);
    }
    return TextSpan(
      children: [
        TextSpan(text: src.substring(0, markerEnd), style: theme.thematicBreakStyle),
        TextSpan(text: src.substring(markerEnd), style: theme.thematicBreakStyle),
      ],
    );
  }

  TextSpan _buildTaskAwareListItemSpan(
    MarkdownBlock block,
    int prefixLen,
    List<MarkdownInline> children,
    TextStyle baseStyle,
    TextStyle delimiterStyle,
    bool revealed, {
    required bool isTask,
    required bool? taskChecked,
  }) {
    final src = block.sourceText;

    // In collapsed mode with a task item, split the prefix to style the
    // checkbox part ([x] or [ ]) differently from the marker.
    if (!revealed && isTask && taskChecked != null) {
      final prefix = src.substring(0, prefixLen);
      // Find the checkbox part within the prefix: "[ ] " or "[x] "
      final checkboxStart = prefix.indexOf('[');
      if (checkboxStart >= 0) {
        final checkboxEnd = prefix.indexOf(']', checkboxStart) + 1;
        final markerPart = prefix.substring(0, checkboxStart);
        final checkboxPart = prefix.substring(checkboxStart, checkboxEnd);
        final spacePart = prefix.substring(checkboxEnd);

        final checkboxStyle = taskChecked
            ? theme.taskCheckedStyle
            : theme.taskUncheckedStyle;

        final inlineSpans = _buildInlineSpanList(
          children,
          baseStyle,
          delimiterStyle,
          revealed,
        );
        final contentEnd = children.isEmpty
            ? prefixLen
            : children.last.sourceStop - block.sourceStart;
        final suffix = src.substring(contentEnd);

        return TextSpan(
          children: [
            TextSpan(text: markerPart, style: delimiterStyle),
            TextSpan(text: checkboxPart, style: checkboxStyle),
            TextSpan(text: spacePart, style: delimiterStyle),
            ...inlineSpans,
            if (suffix.isNotEmpty) TextSpan(text: suffix, style: baseStyle),
          ],
        );
      }
    }

    // Default: non-task or revealed mode.
    final prefix = src.substring(0, prefixLen);
    final inlineSpans = _buildInlineSpanList(
      children,
      baseStyle,
      delimiterStyle,
      revealed,
    );
    final contentEnd = children.isEmpty
        ? prefixLen
        : children.last.sourceStop - block.sourceStart;
    final suffix = src.substring(contentEnd);

    return TextSpan(
      children: [
        TextSpan(text: prefix, style: delimiterStyle),
        ...inlineSpans,
        if (suffix.isNotEmpty) TextSpan(text: suffix, style: baseStyle),
      ],
    );
  }

  TextSpan _buildBlockquoteSpan(
    BlockquoteBlock block,
    TextStyle delimiterStyle,
    bool revealed,
  ) {
    final contentStyle = theme.blockquoteStyle;
    // In collapsed mode, use a visible blockquote marker style instead
    // of hiding the "> " prefix.
    final markerStyle = revealed ? delimiterStyle : theme.blockquoteMarkerStyle;
    final inlineSpans = _buildInlineSpanList(
      block.children,
      contentStyle,
      delimiterStyle,
      revealed,
    );
    // Trailing newline after last inline
    final contentEnd = block.children.isEmpty
        ? 0
        : block.children.last.sourceStop - block.sourceStart;
    final suffix = block.sourceText.substring(contentEnd);

    return TextSpan(
      children: [
        TextSpan(text: '> ', style: markerStyle),
        ...inlineSpans,
        if (suffix.isNotEmpty) TextSpan(text: suffix, style: contentStyle),
      ],
    );
  }

  TextSpan _buildFencedCodeSpan(
    FencedCodeBlock block,
    TextStyle delimiterStyle,
    bool revealed,
  ) {
    // Source: ```lang\ncode\n```\n
    // Split into: openFenceLine + code + closeFenceLine
    final src = block.sourceText;
    final fence = block.fence;
    final infoStr = block.language ?? '';
    final openLine = '$fence$infoStr\n';
    final code = block.code;
    final closeStart = openLine.length + code.length;
    final closeLine = src.substring(closeStart);

    return TextSpan(
      children: [
        TextSpan(text: openLine, style: delimiterStyle),
        TextSpan(text: code, style: theme.codeBlockStyle),
        TextSpan(text: closeLine, style: delimiterStyle),
      ],
    );
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
