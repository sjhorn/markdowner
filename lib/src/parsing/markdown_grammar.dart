import 'package:petitparser/petitparser.dart';

/// Pure grammar definition for the Phase 1 markdown subset.
///
/// Defines syntax structure only — no AST construction.
/// Each method returns a [Parser] that recognizes the syntax.
///
/// Phase 1 supports:
/// - Blocks: paragraphs, ATX headings (#–######), blank lines, thematic breaks
/// - Inlines: plain text, **bold**, *italic*, ***bold-italic***, `inline code`,
///   ~~strikethrough~~, escaped chars
class MarkdownGrammarDefinition extends GrammarDefinition {
  @override
  Parser start() => ref0(document).end();

  Parser document() => ref0(block).star();

  // ─── Block-Level Productions ───
  //
  // Each block consumes through its trailing newline (or end-of-input).
  // Blocks are tried in order; paragraph is the catch-all.

  Parser block() =>
      ref0(blankLine) |
      ref0(atxHeading) |
      ref0(thematicBreak) |
      ref0(paragraph);

  /// A blank line is a bare newline character.
  Parser blankLine() => char('\n');

  /// ATX heading: 1–6 `#` chars, a space, inline content, then line ending.
  Parser atxHeading() =>
      char('#').repeatString(1, 6) &
      char(' ') &
      ref0(inlineContent) &
      ref0(lineEnding);

  /// Thematic break: exactly `---`, `***`, or `___` followed by line ending.
  Parser thematicBreak() =>
      (string('---') | string('***') | string('___')) & ref0(lineEnding);

  /// Paragraph: inline content followed by line ending.
  Parser paragraph() => ref0(inlineContent) & ref0(lineEnding);

  // ─── Inline-Level Productions ───

  /// One or more inline elements.
  Parser inlineContent() => ref0(inline).plus();

  /// A single inline element. Order matters (PEG ordered choice):
  /// try longer/more-specific delimiters before shorter ones.
  Parser inline() =>
      ref0(escapedChar) |
      ref0(boldItalic) |
      ref0(bold) |
      ref0(italic) |
      ref0(strikethrough) |
      ref0(inlineCode) |
      ref0(link) |
      ref0(plainText) |
      ref0(fallbackChar);

  /// Bold-italic: `***content***`. Content is flat text (no nesting in Phase 1).
  Parser boldItalic() =>
      string('***') &
      noneOf('\n').plusLazy(string('***')).flatten() &
      string('***');

  /// Bold: `**content**` or `__content__`. Content is flat text.
  Parser bold() =>
      (string('**') &
          noneOf('\n').plusLazy(string('**')).flatten() &
          string('**')) |
      (string('__') &
          noneOf('\n').plusLazy(string('__')).flatten() &
          string('__'));

  /// Italic: `*content*` or `_content_`.
  /// Content excludes the delimiter char to avoid ambiguity with bold.
  Parser italic() =>
      (char('*') & noneOf('*\n').plusString() & char('*')) |
      (char('_') & noneOf('_\n').plusString() & char('_'));

  /// Strikethrough: `~~content~~`. Content is flat text.
  Parser strikethrough() =>
      string('~~') &
      noneOf('\n').plusLazy(string('~~')).flatten() &
      string('~~');

  /// Inline code: `` `code` `` or ``` ``code`` ```.
  /// Double-backtick variant allows single backticks inside.
  Parser inlineCode() =>
      (string('``') &
          noneOf('\n').plusLazy(string('``')).flatten() &
          string('``')) |
      (char('`') & noneOf('`\n').plusString() & char('`'));

  /// Link: `[text](url)` or `[text](url "title")`.
  Parser link() =>
      char('[') &
      ref0(linkText) &
      char(']') &
      char('(') &
      ref0(linkUrl) &
      ref0(linkTitle).optional() &
      char(')');

  /// Link text: any characters except `]` and newline.
  Parser linkText() => noneOf(']\n').plusString();

  /// Link URL: any characters except `)`, space, and newline.
  Parser linkUrl() => noneOf(') \n').plusString();

  /// Link title: `"title"` with a leading space.
  Parser linkTitle() =>
      char(' ') & char('"') & noneOf('"\n').starString() & char('"');

  /// Escaped character: backslash followed by a markdown-special character.
  Parser escapedChar() => char('\\') & ref0(markdownSpecialChar);

  /// Characters that can be backslash-escaped in markdown.
  Parser markdownSpecialChar() =>
      char('\\') |
      char('`') |
      char('*') |
      char('_') |
      char('{') |
      char('}') |
      char('[') |
      char(']') |
      char('(') |
      char(')') |
      char('#') |
      char('+') |
      char('-') |
      char('.') |
      char('!') |
      char('|') |
      char('~');

  /// A run of non-special, non-newline characters.
  Parser plainText() => noneOf('*_`~\\[\n').plusString();

  /// Fallback: any single non-newline character that didn't start a construct.
  Parser fallbackChar() => noneOf('\n');

  // ─── Helpers ───

  /// End of a line: newline or end of input.
  Parser lineEnding() => char('\n') | endOfInput();
}
