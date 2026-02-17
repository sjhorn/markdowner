import 'package:petitparser/petitparser.dart';

import '../core/markdown_extension.dart';

/// Pure grammar definition for the Phase 1 markdown subset.
///
/// Defines syntax structure only — no AST construction.
/// Each method returns a [Parser] that recognizes the syntax.
///
/// Phase 1 supports:
/// - Blocks: paragraphs, ATX headings (#–######), blank lines, thematic breaks
/// - Inlines: plain text, **bold**, *italic*, ***bold-italic***, `inline code`,
///   ~~strikethrough~~, escaped chars
/// - Extensions: ==highlight==, ~subscript~, ^superscript^, $math$, [^footnotes],
///   :emoji:, YAML front matter, [TOC]
class MarkdownGrammarDefinition extends GrammarDefinition {
  /// Which optional extensions are enabled. Defaults to all.
  final Set<MarkdownExtension> enabledExtensions;

  MarkdownGrammarDefinition({
    Set<MarkdownExtension>? enabledExtensions,
  }) : enabledExtensions = enabledExtensions ?? MarkdownExtension.values.toSet();
  @override
  Parser start() => ref0(document).end();

  Parser document() =>
      ref0(yamlFrontMatter).optional() & ref0(block).star();

  // ─── Block-Level Productions ───
  //
  // Each block consumes through its trailing newline (or end-of-input).
  // Blocks are tried in order; paragraph is the catch-all.

  Parser block() =>
      ref0(blankLine) |
      ref0(atxHeading) |
      ref0(fencedCodeBlock) |
      ref0(mathBlock) |
      ref0(table) |
      ref0(thematicBreak) |
      ref0(blockquote) |
      ref0(unorderedListItem) |
      ref0(orderedListItem) |
      ref0(setextHeading) |
      ref0(footnoteDefinition) |
      ref0(tableOfContents) |
      ref0(paragraph);

  /// A blank line is a bare newline character.
  Parser blankLine() => char('\n');

  /// ATX heading: 1–6 `#` chars, a space, inline content, then line ending.
  Parser atxHeading() =>
      char('#').repeatString(1, 6) &
      char(' ') &
      ref0(inlineContent) &
      ref0(lineEnding);

  /// Fenced code block: opening fence, optional info string, code, closing fence.
  Parser fencedCodeBlock() =>
      ref0(openFence) &
      ref0(infoString).optional() &
      char('\n') &
      ref0(codeContent) &
      ref0(closeFence);

  /// Opening fence: 3+ backticks or 3+ tildes.
  Parser openFence() =>
      (char('`').times(3) & char('`').star()).flatten() |
      (char('~').times(3) & char('~').star()).flatten();

  /// Info string: non-newline characters after the opening fence.
  Parser infoString() => noneOf('\n').plusString();

  /// Code content: everything up to (but not including) the closing fence.
  Parser codeContent() => any().starLazy(ref0(closeFence)).flatten();

  /// Closing fence: newline + 3+ backticks or 3+ tildes + line ending.
  Parser closeFence() =>
      char('\n') &
      ((char('`').times(3) & char('`').star()).flatten() |
          (char('~').times(3) & char('~').star()).flatten()) &
      ref0(lineEnding);

  /// Math display block: `$$\nexpr\n$$`.
  /// Only active when [MarkdownExtension.math] is enabled.
  Parser mathBlock() {
    if (!enabledExtensions.contains(MarkdownExtension.math)) {
      return failure(message: 'math extension disabled');
    }
    return string('\$\$') &
        char('\n') &
        any().starLazy(char('\n') & string('\$\$') & ref0(lineEnding)).flatten() &
        char('\n') &
        string('\$\$') &
        ref0(lineEnding);
  }

  /// GFM table: header row + delimiter row + body rows.
  Parser table() =>
      ref0(tableRow) &
      char('\n') &
      ref0(tableDelimiterRow) &
      (char('\n') & ref0(tableRow)).star();

  /// A table row: everything from `|` to end of line, parsed as a flat string.
  Parser tableRow() => (char('|') & noneOf('\n').star()).flatten();

  /// Table delimiter row: must have `|`, dashes, optional colons.
  /// We validate structure in the parser; grammar just ensures it looks like a delimiter row.
  Parser tableDelimiterRow() =>
      (char('|') & pattern(' :-').plus() & (char('|') & pattern(' :-').star()).star()).flatten();

  /// Thematic break: exactly `---`, `***`, or `___` followed by line ending.
  Parser thematicBreak() =>
      (string('---') | string('***') | string('___')) & ref0(lineEnding);

  /// Blockquote: `> ` followed by inline content and line ending.
  Parser blockquote() =>
      string('> ') & ref0(inlineContent) & ref0(lineEnding);

  /// Unordered list item: optional indent + marker + space + optional checkbox + content.
  Parser unorderedListItem() =>
      ref0(listIndent).optional() &
      (char('-') | char('*') | char('+')) &
      char(' ') &
      ref0(taskCheckbox).optional() &
      ref0(inlineContent) &
      ref0(lineEnding);

  /// Ordered list item: optional indent + digits + punctuation + space + optional checkbox + content.
  Parser orderedListItem() =>
      ref0(listIndent).optional() &
      digit().plusString() &
      (char('.') | char(')')) &
      char(' ') &
      ref0(taskCheckbox).optional() &
      ref0(inlineContent) &
      ref0(lineEnding);

  /// List indentation: 2 or 4 spaces.
  Parser listIndent() => string('    ') | string('  ');

  /// Task checkbox: `[x] ` or `[ ] `.
  Parser taskCheckbox() =>
      (string('[x]') | string('[ ]')) & char(' ');

  /// Setext heading: content line + underline (=== or ---).
  Parser setextHeading() =>
      ref0(inlineContent) &
      char('\n') &
      (char('=').plusString() | char('-').plusString()) &
      ref0(lineEnding);

  /// Footnote definition: `[^ref]: content`.
  /// Only active when [MarkdownExtension.footnotes] is enabled.
  Parser footnoteDefinition() {
    if (!enabledExtensions.contains(MarkdownExtension.footnotes)) {
      return failure(message: 'footnotes extension disabled');
    }
    return string('[^') &
        noneOf(']\n').plusString() &
        string(']: ') &
        ref0(inlineContent) &
        ref0(lineEnding);
  }

  /// Table of contents placeholder: `[TOC]`.
  /// Only active when [MarkdownExtension.tableOfContents] is enabled.
  Parser tableOfContents() {
    if (!enabledExtensions.contains(MarkdownExtension.tableOfContents)) {
      return failure(message: 'tableOfContents extension disabled');
    }
    return string('[TOC]') & ref0(lineEnding);
  }

  /// YAML front matter: `---\ncontent\n---` at document start.
  /// Only active when [MarkdownExtension.yamlFrontMatter] is enabled.
  Parser yamlFrontMatter() {
    if (!enabledExtensions.contains(MarkdownExtension.yamlFrontMatter)) {
      return failure(message: 'yamlFrontMatter extension disabled');
    }
    return string('---') &
        char('\n') &
        any().starLazy(char('\n') & string('---') & ref0(lineEnding)).flatten() &
        char('\n') &
        string('---') &
        ref0(lineEnding);
  }

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
      ref0(subscript) |
      ref0(inlineCode) |
      ref0(inlineMath) |
      ref0(highlight) |
      ref0(image) |
      ref0(footnoteRef) |
      ref0(link) |
      ref0(autolink) |
      ref0(emoji) |
      ref0(superscript) |
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

  /// Highlight: `==content==`. Content is flat text.
  /// Only active when [MarkdownExtension.highlight] is enabled.
  Parser highlight() {
    if (!enabledExtensions.contains(MarkdownExtension.highlight)) {
      return failure(message: 'highlight extension disabled');
    }
    return string('==') &
        noneOf('\n').plusLazy(string('==')).flatten() &
        string('==');
  }

  /// Subscript: `~content~`. Content excludes `~` and newline.
  /// Safe because `~~` (strikethrough) is tried first in [inline()].
  /// Only active when [MarkdownExtension.subscript] is enabled.
  Parser subscript() {
    if (!enabledExtensions.contains(MarkdownExtension.subscript)) {
      return failure(message: 'subscript extension disabled');
    }
    return char('~') & noneOf('~\n').plusString() & char('~');
  }

  /// Superscript: `^content^`. Content excludes `^` and newline.
  /// Only active when [MarkdownExtension.superscript] is enabled.
  Parser superscript() {
    if (!enabledExtensions.contains(MarkdownExtension.superscript)) {
      return failure(message: 'superscript extension disabled');
    }
    return char('^') & noneOf('^\n').plusString() & char('^');
  }

  /// Inline math: `$expr$`. Expression excludes spaces and newlines to avoid
  /// matching `$5 and $10` as math.
  /// Only active when [MarkdownExtension.math] is enabled.
  Parser inlineMath() {
    if (!enabledExtensions.contains(MarkdownExtension.math)) {
      return failure(message: 'math extension disabled');
    }
    return char('\$') & noneOf('\$ \n').plusString() & char('\$');
  }

  /// Footnote reference: `[^ref]`.
  /// Only active when [MarkdownExtension.footnotes] is enabled.
  Parser footnoteRef() {
    if (!enabledExtensions.contains(MarkdownExtension.footnotes)) {
      return failure(message: 'footnotes extension disabled');
    }
    return string('[^') & noneOf(']\n').plusString() & char(']');
  }

  /// Emoji shortcode: `:smile:`.
  /// Only active when [MarkdownExtension.emoji] is enabled.
  Parser emoji() {
    if (!enabledExtensions.contains(MarkdownExtension.emoji)) {
      return failure(message: 'emoji extension disabled');
    }
    return char(':') & pattern('a-zA-Z0-9_+-').plusString() & char(':');
  }

  /// Inline code: `` `code` `` or ``` ``code`` ```.
  /// Double-backtick variant allows single backticks inside.
  Parser inlineCode() =>
      (string('``') &
          noneOf('\n').plusLazy(string('``')).flatten() &
          string('``')) |
      (char('`') & noneOf('`\n').plusString() & char('`'));

  /// Image: `![alt](url)` or `![alt](url "title")`.
  Parser image() =>
      string('![') &
      ref0(imageAlt) &
      char(']') &
      char('(') &
      ref0(imageUrl) &
      ref0(imageTitle).optional() &
      char(')');

  /// Image alt text: any characters except `]` and newline.
  Parser imageAlt() => noneOf(']\n').plusString();

  /// Image URL: any characters except `)`, space, and newline.
  Parser imageUrl() => noneOf(') \n').plusString();

  /// Image title: `"title"` with a leading space.
  Parser imageTitle() =>
      char(' ') & char('"') & noneOf('"\n').starString() & char('"');

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

  /// Autolink: `<url>`.
  Parser autolink() =>
      char('<') & ref0(autolinkUrl) & char('>');

  /// Autolink URL: any characters except `>`, space, and newline.
  Parser autolinkUrl() => noneOf('> \n').plusString();

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
      char('~') |
      char('=') |
      char('^') |
      char('\$') |
      char(':');

  /// A run of non-special, non-newline characters.
  Parser plainText() => noneOf('*_`~=^\$:\\[!<\n').plusString();

  /// Fallback: any single non-newline character that didn't start a construct.
  Parser fallbackChar() => noneOf('\n');

  // ─── Helpers ───

  /// End of a line: newline or end of input.
  Parser lineEnding() => char('\n') | endOfInput();
}
