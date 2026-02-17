import 'package:flutter/painting.dart';

/// Theme configuration for the markdown editor.
///
/// Provides text styles for all markdown constructs in both revealed
/// (cursor inside block) and collapsed (cursor outside) modes.
class MarkdownEditorTheme {
  final TextStyle baseStyle;
  final List<TextStyle> headingStyles;
  final TextStyle boldStyle;
  final TextStyle italicStyle;
  final TextStyle boldItalicStyle;
  final TextStyle inlineCodeStyle;
  final TextStyle strikethroughStyle;
  final TextStyle highlightStyle;
  final TextStyle subscriptStyle;
  final TextStyle superscriptStyle;
  final TextStyle linkStyle;
  final TextStyle codeBlockStyle;
  final TextStyle blockquoteStyle;

  /// Style for inline math expressions (`$expr$`).
  final TextStyle mathStyle;

  /// Style for math display blocks (`$$\nexpr\n$$`).
  final TextStyle mathBlockStyle;

  /// Style for footnote references (`[^ref]`).
  final TextStyle footnoteRefStyle;

  /// Style for footnote definition prefix.
  final TextStyle footnoteDefinitionStyle;

  /// Style for emoji shortcodes (`:smile:`).
  final TextStyle emojiStyle;

  /// Style for YAML front matter content.
  final TextStyle frontMatterStyle;

  /// Style for `[TOC]` placeholder.
  final TextStyle tocStyle;

  /// Style for thematic break markers (`---`, `***`) in collapsed mode.
  final TextStyle thematicBreakStyle;

  /// Style for task checkbox `[ ]` in collapsed mode.
  final TextStyle taskUncheckedStyle;

  /// Style for task checkbox `[x]` in collapsed mode.
  final TextStyle taskCheckedStyle;

  /// Style for the `> ` marker in collapsed blockquotes (visible but muted).
  final TextStyle blockquoteMarkerStyle;

  /// Style for syntax delimiters in revealed mode (muted gray).
  final TextStyle syntaxDelimiterStyle;

  /// Style for syntax delimiters in collapsed mode (near-invisible).
  final TextStyle hiddenSyntaxStyle;

  final Color cursorColor;
  final Color selectionColor;
  final Color backgroundColor;

  const MarkdownEditorTheme({
    required this.baseStyle,
    required this.headingStyles,
    required this.boldStyle,
    required this.italicStyle,
    required this.boldItalicStyle,
    required this.inlineCodeStyle,
    required this.strikethroughStyle,
    required this.highlightStyle,
    required this.subscriptStyle,
    required this.superscriptStyle,
    required this.linkStyle,
    required this.codeBlockStyle,
    required this.blockquoteStyle,
    required this.mathStyle,
    required this.mathBlockStyle,
    required this.footnoteRefStyle,
    required this.footnoteDefinitionStyle,
    required this.emojiStyle,
    required this.frontMatterStyle,
    required this.tocStyle,
    required this.thematicBreakStyle,
    required this.taskUncheckedStyle,
    required this.taskCheckedStyle,
    required this.blockquoteMarkerStyle,
    required this.syntaxDelimiterStyle,
    required this.hiddenSyntaxStyle,
    required this.cursorColor,
    required this.selectionColor,
    required this.backgroundColor,
  }) : assert(headingStyles.length == 6, 'headingStyles must have 6 entries (H1–H6)');

  /// Light theme preset.
  factory MarkdownEditorTheme.light() {
    const base = TextStyle(
      fontSize: 16,
      color: Color(0xFF1A1A1A),
      height: 1.6,
    );
    return MarkdownEditorTheme(
      baseStyle: base,
      headingStyles: [
        base.copyWith(fontSize: 32, fontWeight: FontWeight.bold, height: 1.3),
        base.copyWith(fontSize: 28, fontWeight: FontWeight.bold, height: 1.3),
        base.copyWith(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4),
        base.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
        base.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5),
        base.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5),
      ],
      boldStyle: base.copyWith(fontWeight: FontWeight.bold),
      italicStyle: base.copyWith(fontStyle: FontStyle.italic),
      boldItalicStyle: base.copyWith(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      ),
      inlineCodeStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        backgroundColor: const Color(0xFFF0F0F0),
      ),
      strikethroughStyle: base.copyWith(
        decoration: TextDecoration.lineThrough,
        color: const Color(0xFF888888),
      ),
      highlightStyle: base.copyWith(
        backgroundColor: const Color(0xFFFFEB3B),
      ),
      subscriptStyle: base.copyWith(
        fontSize: 12,
      ),
      superscriptStyle: base.copyWith(
        fontSize: 12,
      ),
      linkStyle: base.copyWith(
        color: const Color(0xFF2196F3),
        decoration: TextDecoration.underline,
      ),
      codeBlockStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        backgroundColor: const Color(0xFFF5F5F5),
      ),
      blockquoteStyle: base.copyWith(
        fontStyle: FontStyle.italic,
        color: const Color(0xFF666666),
      ),
      mathStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: const Color(0xFF6A1B9A),
      ),
      mathBlockStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: const Color(0xFF6A1B9A),
      ),
      footnoteRefStyle: base.copyWith(
        fontSize: 12,
        color: const Color(0xFF2196F3),
      ),
      footnoteDefinitionStyle: base.copyWith(
        color: const Color(0xFF666666),
      ),
      emojiStyle: base.copyWith(
        color: const Color(0xFFE65100),
      ),
      frontMatterStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: const Color(0xFF888888),
      ),
      tocStyle: base.copyWith(
        fontWeight: FontWeight.w600,
        color: const Color(0xFF2196F3),
      ),
      thematicBreakStyle: base.copyWith(
        decoration: TextDecoration.lineThrough,
        decorationColor: const Color(0xFFCCCCCC),
        decorationThickness: 2.0,
        color: const Color(0x00000000),
        letterSpacing: 4.0,
      ),
      taskUncheckedStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: const Color(0xFF999999),
      ),
      taskCheckedStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: const Color(0xFF4CAF50),
        fontWeight: FontWeight.bold,
      ),
      blockquoteMarkerStyle: base.copyWith(
        color: const Color(0xFF2196F3),
        fontWeight: FontWeight.bold,
      ),
      syntaxDelimiterStyle: base.copyWith(
        color: const Color(0xFFAAAAAA),
      ),
      hiddenSyntaxStyle: base.copyWith(
        fontSize: 0.01,
        color: const Color(0x00000000),
      ),
      cursorColor: const Color(0xFF1A1A1A),
      selectionColor: const Color(0x40448AFF),
      backgroundColor: const Color(0xFFFFFFFF),
    );
  }

  /// Dark theme preset.
  factory MarkdownEditorTheme.dark() {
    const base = TextStyle(
      fontSize: 16,
      color: Color(0xFFE0E0E0),
      height: 1.6,
    );
    return MarkdownEditorTheme(
      baseStyle: base,
      headingStyles: [
        base.copyWith(fontSize: 32, fontWeight: FontWeight.bold, height: 1.3),
        base.copyWith(fontSize: 28, fontWeight: FontWeight.bold, height: 1.3),
        base.copyWith(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4),
        base.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
        base.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5),
        base.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5),
      ],
      boldStyle: base.copyWith(fontWeight: FontWeight.bold),
      italicStyle: base.copyWith(fontStyle: FontStyle.italic),
      boldItalicStyle: base.copyWith(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      ),
      inlineCodeStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        backgroundColor: const Color(0xFF2A2A2A),
      ),
      strikethroughStyle: base.copyWith(
        decoration: TextDecoration.lineThrough,
        color: const Color(0xFF888888),
      ),
      highlightStyle: base.copyWith(
        backgroundColor: const Color(0xFF827717),
      ),
      subscriptStyle: base.copyWith(
        fontSize: 12,
      ),
      superscriptStyle: base.copyWith(
        fontSize: 12,
      ),
      linkStyle: base.copyWith(
        color: const Color(0xFF64B5F6),
        decoration: TextDecoration.underline,
      ),
      codeBlockStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        backgroundColor: const Color(0xFF2D2D2D),
      ),
      blockquoteStyle: base.copyWith(
        fontStyle: FontStyle.italic,
        color: const Color(0xFF999999),
      ),
      mathStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: const Color(0xFFCE93D8),
      ),
      mathBlockStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: const Color(0xFFCE93D8),
      ),
      footnoteRefStyle: base.copyWith(
        fontSize: 12,
        color: const Color(0xFF64B5F6),
      ),
      footnoteDefinitionStyle: base.copyWith(
        color: const Color(0xFF999999),
      ),
      emojiStyle: base.copyWith(
        color: const Color(0xFFFFAB40),
      ),
      frontMatterStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: const Color(0xFF777777),
      ),
      tocStyle: base.copyWith(
        fontWeight: FontWeight.w600,
        color: const Color(0xFF64B5F6),
      ),
      thematicBreakStyle: base.copyWith(
        decoration: TextDecoration.lineThrough,
        decorationColor: const Color(0xFF555555),
        decorationThickness: 2.0,
        color: const Color(0x00000000),
        letterSpacing: 4.0,
      ),
      taskUncheckedStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: const Color(0xFF777777),
      ),
      taskCheckedStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: const Color(0xFF81C784),
        fontWeight: FontWeight.bold,
      ),
      blockquoteMarkerStyle: base.copyWith(
        color: const Color(0xFF64B5F6),
        fontWeight: FontWeight.bold,
      ),
      syntaxDelimiterStyle: base.copyWith(
        color: const Color(0xFF666666),
      ),
      hiddenSyntaxStyle: base.copyWith(
        fontSize: 0.01,
        color: const Color(0x00000000),
      ),
      cursorColor: const Color(0xFFE0E0E0),
      selectionColor: const Color(0x40448AFF),
      backgroundColor: const Color(0xFF1E1E1E),
    );
  }

  /// Creates a copy with the given fields replaced.
  MarkdownEditorTheme copyWith({
    TextStyle? baseStyle,
    List<TextStyle>? headingStyles,
    TextStyle? boldStyle,
    TextStyle? italicStyle,
    TextStyle? boldItalicStyle,
    TextStyle? inlineCodeStyle,
    TextStyle? strikethroughStyle,
    TextStyle? highlightStyle,
    TextStyle? subscriptStyle,
    TextStyle? superscriptStyle,
    TextStyle? linkStyle,
    TextStyle? codeBlockStyle,
    TextStyle? blockquoteStyle,
    TextStyle? mathStyle,
    TextStyle? mathBlockStyle,
    TextStyle? footnoteRefStyle,
    TextStyle? footnoteDefinitionStyle,
    TextStyle? emojiStyle,
    TextStyle? frontMatterStyle,
    TextStyle? tocStyle,
    TextStyle? thematicBreakStyle,
    TextStyle? taskUncheckedStyle,
    TextStyle? taskCheckedStyle,
    TextStyle? blockquoteMarkerStyle,
    TextStyle? syntaxDelimiterStyle,
    TextStyle? hiddenSyntaxStyle,
    Color? cursorColor,
    Color? selectionColor,
    Color? backgroundColor,
  }) {
    return MarkdownEditorTheme(
      baseStyle: baseStyle ?? this.baseStyle,
      headingStyles: headingStyles ?? this.headingStyles,
      boldStyle: boldStyle ?? this.boldStyle,
      italicStyle: italicStyle ?? this.italicStyle,
      boldItalicStyle: boldItalicStyle ?? this.boldItalicStyle,
      inlineCodeStyle: inlineCodeStyle ?? this.inlineCodeStyle,
      strikethroughStyle: strikethroughStyle ?? this.strikethroughStyle,
      highlightStyle: highlightStyle ?? this.highlightStyle,
      subscriptStyle: subscriptStyle ?? this.subscriptStyle,
      superscriptStyle: superscriptStyle ?? this.superscriptStyle,
      linkStyle: linkStyle ?? this.linkStyle,
      codeBlockStyle: codeBlockStyle ?? this.codeBlockStyle,
      blockquoteStyle: blockquoteStyle ?? this.blockquoteStyle,
      mathStyle: mathStyle ?? this.mathStyle,
      mathBlockStyle: mathBlockStyle ?? this.mathBlockStyle,
      footnoteRefStyle: footnoteRefStyle ?? this.footnoteRefStyle,
      footnoteDefinitionStyle: footnoteDefinitionStyle ?? this.footnoteDefinitionStyle,
      emojiStyle: emojiStyle ?? this.emojiStyle,
      frontMatterStyle: frontMatterStyle ?? this.frontMatterStyle,
      tocStyle: tocStyle ?? this.tocStyle,
      thematicBreakStyle: thematicBreakStyle ?? this.thematicBreakStyle,
      taskUncheckedStyle: taskUncheckedStyle ?? this.taskUncheckedStyle,
      taskCheckedStyle: taskCheckedStyle ?? this.taskCheckedStyle,
      blockquoteMarkerStyle: blockquoteMarkerStyle ?? this.blockquoteMarkerStyle,
      syntaxDelimiterStyle: syntaxDelimiterStyle ?? this.syntaxDelimiterStyle,
      hiddenSyntaxStyle: hiddenSyntaxStyle ?? this.hiddenSyntaxStyle,
      cursorColor: cursorColor ?? this.cursorColor,
      selectionColor: selectionColor ?? this.selectionColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}
