# Flutter Markdown WYSIWYG Editor — Specification

## Project Overview

Build a Flutter widget that provides a **Typora-style WYSIWYG markdown editing experience** built on top of `EditableText`. The editor renders markdown as rich formatted text in real-time while preserving the underlying markdown source. When the cursor enters a markdown element, the raw syntax is revealed for editing; when the cursor leaves, it renders visually.

**Parsing engine:** [PetitParser](https://pub.dev/packages/petitparser) — a parser combinator framework used to define the markdown grammar as composable, testable Dart code. PetitParser's `Token` class provides built-in source position tracking (`start`, `stop`) which maps directly to the reveal/hide mechanic.

**Package name:** `markdowner`
**Min Flutter SDK:** 3.38+
**Min Dart SDK:** 3.5+
**Target platforms:** iOS, Android, macOS, Windows, Linux, Web

---

## Core Design Principles

1. **Single-source-of-truth:** The canonical data is always a markdown string. The rendered view is a derived projection.
2. **Inline reveal/hide:** When the cursor is inside a markdown construct (e.g., `**bold**`), the syntax characters are visible and editable. When the cursor moves out, they collapse into rendered form (e.g., **bold**).
3. **Block-level transitions:** Block elements (headings, code blocks, lists, blockquotes) switch between "editing mode" (raw syntax visible) and "rendered mode" based on cursor/focus position at the block level.
4. **No mode toggle:** Unlike split-pane editors, there is no separate "preview" mode. Editing and viewing are unified (Typora-style).
5. **Built on EditableText:** Leverage Flutter's `EditableText` (or `TextEditingController` + custom `TextSpan` tree) for native text input, IME, selection, clipboard, and accessibility.
6. **PetitParser-driven grammar:** The markdown grammar is defined declaratively using PetitParser combinators. Each production returns AST nodes with source position tracking via PetitParser's `Token`. This makes the grammar modular, testable per-production, and extensible.

---

## Architecture

### High-Level Component Diagram

```
┌───────────────────────────────────────────────────────────────┐
│                    MarkdownEditor (Widget)                     │
│                                                               │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │           PetitParser Grammar Layer                       │ │
│  │                                                          │ │
│  │  MarkdownGrammarDefinition (extends GrammarDefinition)   │ │
│  │  ├── Block-level productions (heading, codeBlock, ...)   │ │
│  │  └── Inline-level productions (bold, italic, link, ...)  │ │
│  │                                                          │ │
│  │  MarkdownParserDefinition (extends MarkdownGrammarDef)   │ │
│  │  └── .map() / .token() transforms → AST nodes            │ │
│  └──────────────────────────────────────────────────────────┘ │
│                           │                                   │
│                           ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │             MarkdownDocument (AST)                        │ │
│  │                                                          │ │
│  │  List<MarkdownBlock>                                     │ │
│  │  ├── Each block has Token metadata (start/stop offsets)  │ │
│  │  └── Each inline has Token metadata (start/stop offsets) │ │
│  │                                                          │ │
│  │  Bidirectional: parse ↔ serialize (toMarkdown())         │ │
│  └──────────────────────────────────────────────────────────┘ │
│                           │                                   │
│  ┌────────────────────────▼─────────────────────────────────┐ │
│  │         MarkdownEditingController                         │ │
│  │         (extends TextEditingController)                    │ │
│  │                                                          │ │
│  │  - Overrides buildTextSpan() using AST + cursor position │ │
│  │  - Determines active block/inline via Token start/stop   │ │
│  │  - Delegates re-parse to IncrementalParseEngine          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                           │                                   │
│  ┌────────────────────────▼─────────────────────────────────┐ │
│  │         MarkdownRenderEngine                              │ │
│  │                                                          │ │
│  │  - Converts AST blocks → TextSpan / WidgetSpan tree      │ │
│  │  - Uses Token offsets for focus-aware reveal/collapse     │ │
│  │  - Syntax highlighting for revealed regions               │ │
│  └──────────────────────────────────────────────────────────┘ │
│                           │                                   │
│  ┌────────────────────────▼─────────────────────────────────┐ │
│  │         Custom EditableText / TextField                   │ │
│  │         (renders the TextSpan tree)                       │ │
│  └──────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

### Key Classes

| Class | Responsibility |
|---|---|
| `MarkdownEditor` | Top-level stateful widget. Public API entry point. |
| `MarkdownEditorState` | Manages controller, focus, scroll, undo/redo stack. |
| `MarkdownEditingController` | Extends `TextEditingController`. Overrides `buildTextSpan()` to return styled spans. Tracks cursor position to determine which block/inline is "active" (revealed). |
| `MarkdownGrammarDefinition` | PetitParser `GrammarDefinition` subclass. Defines raw markdown grammar productions (syntax only, no AST construction). |
| `MarkdownParserDefinition` | Extends `MarkdownGrammarDefinition`. Overrides productions with `.token()` and `.map()` to produce AST nodes with source positions. |
| `MarkdownDocument` | Parsed AST. A list of `MarkdownBlock` nodes. Bidirectional: parse from string, serialize back to string. |
| `MarkdownBlock` | Abstract base for block-level AST nodes. Carries a `Token` with `start`/`stop` offsets. |
| `MarkdownInline` | Abstract base for inline-level AST nodes. Carries a `Token` with `start`/`stop` offsets. |
| `IncrementalParseEngine` | Manages efficient re-parsing. On each edit, determines which blocks are affected, re-runs only the relevant PetitParser productions on those regions. |
| `MarkdownRenderEngine` | Converts `MarkdownDocument` → `InlineSpan` tree (TextSpan + WidgetSpan). Accepts the "active block index" to decide reveal/collapse. |
| `MarkdownEditorTheme` | Theming data class for all visual aspects (fonts, colors, spacing). |
| `MarkdownEditorConfig` | Configuration: enabled syntax features, toolbar config, shortcuts, etc. |

---

## PetitParser Grammar Design

### Why PetitParser

PetitParser is the right tool for this project because:

1. **Built-in source tracking:** The `.token()` combinator wraps any parse result in a `Token` object that carries `start`, `stop`, `buffer` (the original input), and `value` (the parsed result). This maps directly to the reveal/hide mechanic — every AST node knows exactly where its syntax characters live in the source.
2. **Composable grammar:** Productions can be developed and tested independently (`definition.buildFrom(definition.bold)`), then composed into the full grammar.
3. **PEG semantics:** Ordered choice (`|`) with no ambiguity — the first matching alternative wins. This aligns well with markdown's parsing priority rules.
4. **Dynamic reconfiguration:** Grammar productions can be swapped at runtime, enabling feature flags (e.g., enable/disable math, footnotes, etc.) without code changes.
5. **Linter:** PetitParser's built-in linter detects infinite loops, unreachable parsers, and other grammar bugs during development/testing.
6. **Mature & well-tested:** Widely used in the Dart ecosystem, with JSON, Dart, Smalltalk, and Lisp grammars as reference implementations.

### Grammar/Parser Separation Pattern

Following PetitParser best practices, the grammar is split into two classes:

```dart
/// Pure grammar — defines syntax structure only.
/// No AST construction, no side effects.
/// Each method returns a Parser that recognizes the syntax.
class MarkdownGrammarDefinition extends GrammarDefinition {
  @override
  Parser start() => ref0(document).end();

  Parser document() => ref0(block).star();

  // ─── Block-Level Productions ───

  Parser block() =>
      ref0(blankLine) |
      ref0(atxHeading) |
      ref0(fencedCodeBlock) |
      ref0(thematicBreak) |
      ref0(blockquote) |
      ref0(unorderedListItem) |
      ref0(orderedListItem) |
      ref0(table) |
      ref0(paragraph);

  Parser atxHeading() =>
      ref0(lineStart) &
      char('#').repeat(1, 6).flatten() &
      char(' ') &
      ref0(inlineContent) &
      ref0(lineEnd);

  Parser fencedCodeBlock() =>
      ref0(lineStart) &
      (string('```') | string('~~~')) &
      ref0(infoString).optional() &
      ref0(lineEnd) &
      ref0(codeBlockContent) &
      ref0(lineStart) &
      (string('```') | string('~~~')) &
      ref0(lineEnd);

  Parser thematicBreak() =>
      ref0(lineStart) &
      (string('---') | string('***') | string('___')) &
      ref0(lineEnd);

  Parser blockquote() =>
      ref0(lineStart) &
      string('> ') &
      ref0(inlineContent) &
      ref0(lineEnd);

  Parser unorderedListItem() =>
      ref0(lineStart) &
      ref0(listIndent).optional() &
      (char('-') | char('*') | char('+')) &
      char(' ') &
      ref0(taskCheckbox).optional() &
      ref0(inlineContent) &
      ref0(lineEnd);

  Parser orderedListItem() =>
      ref0(lineStart) &
      ref0(listIndent).optional() &
      digit().plus().flatten() &
      (char('.') | char(')')) &
      char(' ') &
      ref0(inlineContent) &
      ref0(lineEnd);

  Parser paragraph() =>
      ref0(inlineContent) & ref0(lineEnd);

  // ─── Inline-Level Productions ───

  Parser inlineContent() => ref0(inline).plus();

  Parser inline() =>
      ref0(escapedChar) |
      ref0(boldItalic) |
      ref0(bold) |
      ref0(italic) |
      ref0(strikethrough) |
      ref0(inlineCode) |
      ref0(image) |
      ref0(link) |
      ref0(autolink) |
      ref0(hardLineBreak) |
      ref0(inlineMath) |
      ref0(highlight) |
      ref0(plainText);

  Parser bold() =>
      string('**') & ref0(boldContent) & string('**') |
      string('__') & ref0(boldContent) & string('__');

  Parser italic() =>
      char('*') & ref0(italicContent) & char('*') |
      char('_') & ref0(italicContent) & char('_');

  Parser boldItalic() =>
      string('***') & ref0(boldItalicContent) & string('***');

  Parser strikethrough() =>
      string('~~') & ref0(strikethroughContent) & string('~~');

  Parser inlineCode() =>
      char('`') & ref0(inlineCodeContent) & char('`') |
      string('``') & ref0(inlineCodeContent2) & string('``');

  Parser link() =>
      char('[') & ref0(linkText) & char(']') &
      char('(') & ref0(linkUrl) & ref0(linkTitle).optional() & char(')');

  Parser image() =>
      string('![') & ref0(imageAlt) & char(']') &
      char('(') & ref0(imageUrl) & ref0(imageTitle).optional() & char(')');

  Parser autolink() =>
      char('<') & ref0(autolinkUrl) & char('>');

  // ─── Helper Productions ───

  Parser lineStart() => /* beginning of line or start of input */;
  Parser lineEnd() => char('\n') | endOfInput();
  Parser blankLine() => ref0(lineStart) & char('\n');
  Parser listIndent() => string('  ').plus() | char('\t').plus();
  Parser taskCheckbox() => (string('[x]') | string('[ ]')) & char(' ');
  Parser escapedChar() => char('\\') & any();
  Parser hardLineBreak() => string('  ') & char('\n');
  Parser plainText() => /* any char not matched by other inlines */;

  // ... additional helper productions
}
```

```dart
/// Parser definition — extends grammar with AST construction.
/// Uses .token() to capture source positions and .map() to build AST nodes.
class MarkdownParserDefinition extends MarkdownGrammarDefinition {

  @override
  Parser document() => super.document().map(
    (blocks) => MarkdownDocument(blocks: blocks.cast<MarkdownBlock>()),
  );

  @override
  Parser atxHeading() => super.atxHeading().token().map((token) {
    final parts = token.value as List;
    final level = (parts[1] as String).length; // count of '#' chars
    final content = parts[3] as List<MarkdownInline>;
    return HeadingBlock(
      level: level,
      children: content,
      sourceToken: token, // Token carries start, stop, buffer
    );
  });

  @override
  Parser bold() => super.bold().token().map((token) {
    final parts = token.value as List;
    final delimiter = parts[0] as String; // '**' or '__'
    final content = parts[1] as List<MarkdownInline>;
    return BoldInline(
      delimiter: delimiter,
      children: content,
      sourceToken: token,
    );
  });

  @override
  Parser link() => super.link().token().map((token) {
    final parts = token.value as List;
    return LinkInline(
      text: parts[1] as String,
      url: parts[4] as String,
      title: parts[5] as String?,
      sourceToken: token,
    );
  });

  // ... similar .token().map() overrides for all productions
}
```

### Key PetitParser Patterns Used

| Pattern | Usage | Example |
|---|---|---|
| `.token()` | Wrap parse result in `Token` with `start`/`stop` offsets | `bold().token()` → `Token(value: BoldInline(...), start: 10, stop: 22)` |
| `.flatten()` | Collapse matched chars into a single string | `char('#').repeat(1,6).flatten()` → `"###"` |
| `.map()` | Transform parse result into AST node | `.map((v) => HeadingBlock(...))` |
| `.token().map()` | Capture position then build AST node (this is the primary pattern) | Every production in `MarkdownParserDefinition` |
| `ref0()` | Reference another production (enables recursion and lazy resolution) | `ref0(inlineContent)` inside `bold()` |
| `.optional()` | Make a production optional | `ref0(linkTitle).optional()` |
| `.star()` / `.plus()` | Repeat 0+ or 1+ times | `ref0(block).star()` for document body |
| `.repeat(min, max)` | Bounded repetition | `char('#').repeat(1, 6)` for heading level |
| `string()` / `char()` | Match exact string or character | `string('**')`, `char('>')` |
| `.end()` | Assert end of input | `ref0(document).end()` in `start()` |
| `.starLazy(limit)` | Lazy repetition — stop at delimiter | `ref0(inline).starLazy(string('**'))` for bold content |
| `position()` | Capture current parse position | Used in incremental parsing for block boundaries |
| `GrammarDefinition.buildFrom()` | Build parser from a single production for isolated testing | `definition.buildFrom(definition.bold)` |
| PetitParser `linter()` | Validate grammar for infinite loops, unreachable parsers, etc. | Run in test suite |

### Building and Using the Parser

```dart
// Build the full parser
final definition = MarkdownParserDefinition();
final parser = definition.build();

// Parse a document
final result = parser.parse(markdownString);
if (result.isSuccess) {
  final document = result.value as MarkdownDocument;
  // document.blocks contains all parsed blocks with Token metadata
}

// Build and test a single production in isolation
final boldParser = definition.buildFrom(definition.bold);
final boldResult = boldParser.parse('**hello world**');
assert(boldResult.isSuccess);
final boldNode = boldResult.value as BoldInline;
assert(boldNode.sourceToken.start == 0);
assert(boldNode.sourceToken.stop == 15);
```

---

## Data Model: AST Nodes

### Base Types with Token Metadata

Every AST node carries a PetitParser `Token` that records its exact position in the source string:

```dart
import 'package:petitparser/petitparser.dart';

/// Base class for all AST nodes.
/// Every node carries its PetitParser Token for source position tracking.
sealed class MarkdownNode {
  /// PetitParser Token from the parse.
  /// token.start = offset of first character (inclusive)
  /// token.stop  = offset past last character (exclusive)
  /// token.input = the raw source substring
  /// token.buffer = the full input string
  final Token sourceToken;

  MarkdownNode({required this.sourceToken});

  /// Offset of the first character of this node in the source string.
  int get sourceStart => sourceToken.start;

  /// Offset past the last character of this node in the source string.
  int get sourceStop => sourceToken.stop;

  /// The raw source text of this node (including all syntax characters).
  String get sourceText => sourceToken.input;
}
```

### Block-Level AST Nodes

```dart
sealed class MarkdownBlock extends MarkdownNode {
  MarkdownBlock({required super.sourceToken});

  /// The inline children of this block (if applicable).
  List<MarkdownInline> get children;
}

class HeadingBlock extends MarkdownBlock {
  final int level; // 1-6
  final String delimiter; // '#' through '######' — preserved for roundtrip
  @override
  final List<MarkdownInline> children;

  /// Offset where the content text starts (after '# ').
  /// Derived from Token: sourceStart + delimiter.length + 1 (for the space).
  int get contentStart => sourceStart + delimiter.length + 1;
  int get contentStop => sourceStop; // trailing newline excluded by production

  HeadingBlock({
    required this.level,
    required this.delimiter,
    required this.children,
    required super.sourceToken,
  });
}

class ParagraphBlock extends MarkdownBlock {
  @override
  final List<MarkdownInline> children;
  ParagraphBlock({required this.children, required super.sourceToken});
}

class FencedCodeBlock extends MarkdownBlock {
  final String fence;     // '```' or '~~~' — preserved for roundtrip
  final String? language; // info string after fence
  final String code;      // raw code content (no inlines parsed)

  @override
  List<MarkdownInline> get children => []; // code blocks have no inline children

  /// Offsets for the code content region (between fences).
  int get codeStart; // offset after opening fence + newline
  int get codeStop;  // offset before closing fence

  FencedCodeBlock({
    required this.fence,
    this.language,
    required this.code,
    required super.sourceToken,
  });
}

class BlockquoteBlock extends MarkdownBlock {
  final List<MarkdownBlock> nestedBlocks; // blockquotes can contain blocks

  @override
  List<MarkdownInline> get children => []; // content is in nestedBlocks

  BlockquoteBlock({required this.nestedBlocks, required super.sourceToken});
}

class ListBlock extends MarkdownBlock {
  final bool ordered;
  final int? startNumber; // for ordered lists
  final List<ListItemBlock> items;

  @override
  List<MarkdownInline> get children => [];

  ListBlock({
    required this.ordered,
    this.startNumber,
    required this.items,
    required super.sourceToken,
  });
}

class ListItemBlock extends MarkdownBlock {
  final String marker;     // '-', '*', '+', '1.', '2)' — preserved for roundtrip
  final bool? isTask;      // null = not a task, true = checked, false = unchecked
  final int indentLevel;
  @override
  final List<MarkdownInline> children;
  final List<MarkdownBlock> subBlocks; // nested lists, paragraphs within item

  ListItemBlock({
    required this.marker,
    this.isTask,
    required this.indentLevel,
    required this.children,
    this.subBlocks = const [],
    required super.sourceToken,
  });
}

class ThematicBreakBlock extends MarkdownBlock {
  final String marker; // '---', '***', or '___' — preserved for roundtrip

  @override
  List<MarkdownInline> get children => [];

  ThematicBreakBlock({required this.marker, required super.sourceToken});
}

class TableBlock extends MarkdownBlock {
  final List<TableRow> rows;
  final List<TableAlignment?> columnAlignments;

  @override
  List<MarkdownInline> get children => [];

  TableBlock({
    required this.rows,
    required this.columnAlignments,
    required super.sourceToken,
  });
}

class BlankLineBlock extends MarkdownBlock {
  @override
  List<MarkdownInline> get children => [];
  BlankLineBlock({required super.sourceToken});
}
```

### Inline-Level AST Nodes

```dart
sealed class MarkdownInline extends MarkdownNode {
  MarkdownInline({required super.sourceToken});
}

class PlainTextInline extends MarkdownInline {
  final String text;
  PlainTextInline({required this.text, required super.sourceToken});
}

class BoldInline extends MarkdownInline {
  final String delimiter; // '**' or '__' — preserved for roundtrip
  final List<MarkdownInline> children;

  /// Content region (excluding delimiters).
  int get contentStart => sourceStart + delimiter.length;
  int get contentStop => sourceStop - delimiter.length;

  BoldInline({
    required this.delimiter,
    required this.children,
    required super.sourceToken,
  });
}

class ItalicInline extends MarkdownInline {
  final String delimiter; // '*' or '_'
  final List<MarkdownInline> children;

  int get contentStart => sourceStart + delimiter.length;
  int get contentStop => sourceStop - delimiter.length;

  ItalicInline({
    required this.delimiter,
    required this.children,
    required super.sourceToken,
  });
}

class BoldItalicInline extends MarkdownInline {
  final List<MarkdownInline> children;

  int get contentStart => sourceStart + 3; // skip '***'
  int get contentStop => sourceStop - 3;

  BoldItalicInline({required this.children, required super.sourceToken});
}

class InlineCodeInline extends MarkdownInline {
  final String delimiter; // '`' or '``'
  final String code;

  int get contentStart => sourceStart + delimiter.length;
  int get contentStop => sourceStop - delimiter.length;

  InlineCodeInline({
    required this.delimiter,
    required this.code,
    required super.sourceToken,
  });
}

class StrikethroughInline extends MarkdownInline {
  final List<MarkdownInline> children;

  int get contentStart => sourceStart + 2; // skip '~~'
  int get contentStop => sourceStop - 2;

  StrikethroughInline({required this.children, required super.sourceToken});
}

class LinkInline extends MarkdownInline {
  final List<MarkdownInline> textChildren; // inline content in [...]
  final String url;
  final String? title;

  LinkInline({
    required this.textChildren,
    required this.url,
    this.title,
    required super.sourceToken,
  });
}

class ImageInline extends MarkdownInline {
  final String alt;
  final String url;
  final String? title;

  ImageInline({
    required this.alt,
    required this.url,
    this.title,
    required super.sourceToken,
  });
}

class AutolinkInline extends MarkdownInline {
  final String url