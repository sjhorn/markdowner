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
  final TextStyle linkStyle;
  final TextStyle codeBlockStyle;
  final TextStyle blockquoteStyle;

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
    required this.linkStyle,
    required this.codeBlockStyle,
    required this.blockquoteStyle,
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
    TextStyle? linkStyle,
    TextStyle? codeBlockStyle,
    TextStyle? blockquoteStyle,
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
      linkStyle: linkStyle ?? this.linkStyle,
      codeBlockStyle: codeBlockStyle ?? this.codeBlockStyle,
      blockquoteStyle: blockquoteStyle ?? this.blockquoteStyle,
      syntaxDelimiterStyle: syntaxDelimiterStyle ?? this.syntaxDelimiterStyle,
      hiddenSyntaxStyle: hiddenSyntaxStyle ?? this.hiddenSyntaxStyle,
      cursorColor: cursorColor ?? this.cursorColor,
      selectionColor: selectionColor ?? this.selectionColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}
