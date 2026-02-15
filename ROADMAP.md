# Flutter Markdown WYSIWYG Editor — Specification

## Project Overview

Build a Flutter widget that provides a **Typora-style WYSIWYG markdown editing experience** built on top of `EditableText`. The editor renders markdown as rich formatted text in real-time while preserving the underlying markdown source. When the cursor enters a markdown element, the raw syntax is revealed for editing; when the cursor leaves, it renders visually.

**Parsing engine:** [PetitParser](https://pub.dev/packages/petitparser) — a parser combinator framework used to define the markdown grammar as composable, testable Dart code. PetitParser's `Token` class provides built-in source position tracking (`start`, `stop`) which maps directly to the reveal/hide mechanic.

**Package name:** `markdowner`
**Min Flutter SDK:** 3.22+
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
  final String url;
  AutolinkInline({required this.url, required super.sourceToken});
}

class HardLineBreakInline extends MarkdownInline {
  HardLineBreakInline({required super.sourceToken});
}

class EscapedCharInline extends MarkdownInline {
  final String character; // the character after '\'
  EscapedCharInline({required this.character, required super.sourceToken});
}

class InlineMathInline extends MarkdownInline {
  final String expression;

  int get contentStart => sourceStart + 1; // skip '$'
  int get contentStop => sourceStop - 1;

  InlineMathInline({required this.expression, required super.sourceToken});
}

class HighlightInline extends MarkdownInline {
  final List<MarkdownInline> children;

  int get contentStart => sourceStart + 2; // skip '=='
  int get contentStop => sourceStop - 2;

  HighlightInline({required this.children, required super.sourceToken});
}

class FootnoteRefInline extends MarkdownInline {
  final String label;
  FootnoteRefInline({required this.label, required super.sourceToken});
}

class EmojiInline extends MarkdownInline {
  final String shortcode; // e.g., 'smile' from ':smile:'
  EmojiInline({required this.shortcode, required super.sourceToken});
}
```

### Table Support Types

```dart
enum TableAlignment { left, center, right }

class TableRow {
  final List<TableCell> cells;
  final bool isHeader;
  TableRow({required this.cells, this.isHeader = false});
}

class TableCell {
  final List<MarkdownInline> children;
  TableCell({required this.children});
}
```

### MarkdownDocument

```dart
class MarkdownDocument {
  final List<MarkdownBlock> blocks;

  MarkdownDocument({required this.blocks});

  /// Serialize back to the exact original markdown string.
  /// Uses sourceToken.input from each block to reconstruct.
  String toMarkdown() {
    return blocks.map((b) => b.sourceText).join();
  }

  /// Find the block that contains the given source offset.
  int? blockIndexAtOffset(int offset) {
    for (var i = 0; i < blocks.length; i++) {
      if (offset >= blocks[i].sourceStart && offset < blocks[i].sourceStop) {
        return i;
      }
    }
    return null;
  }

  /// Find the inline node at the given offset within a block.
  MarkdownInline? inlineAtOffset(int blockIndex, int offset) {
    final block = blocks[blockIndex];
    for (final inline in block.children) {
      if (offset >= inline.sourceStart && offset < inline.sourceStop) {
        return inline;
      }
    }
    return null;
  }
}
```

---

## Incremental Parsing Engine

### Strategy

Full re-parsing the entire document on every keystroke is too expensive for large documents. The `IncrementalParseEngine` provides efficient re-parsing:

```dart
class IncrementalParseEngine {
  final MarkdownParserDefinition _definition;
  late final Parser _blockParser;
  MarkdownDocument _document;

  IncrementalParseEngine(this._definition)
      : _blockParser = _definition.buildFrom(_definition.block());

  /// Re-parse after a text edit.
  /// [editStart] and [editEnd] are the range in the old text that was replaced.
  /// [newText] is the replacement text.
  /// Returns a new MarkdownDocument with only affected blocks re-parsed.
  MarkdownDocument reparse({
    required String oldText,
    required String newText,
    required int editStart,
    required int editEnd,
    required String insertedText,
  }) {
    // 1. Find which blocks are affected by the edit range
    final affectedStart = _findBlockContaining(editStart);
    final affectedEnd = _findBlockContaining(editEnd);

    // 2. Extract the region from the NEW text that covers those blocks
    //    (with some padding for block boundary detection)
    final regionStart = _document.blocks[affectedStart].sourceStart;
    final regionEnd = _adjustedEnd(affectedEnd, editEnd, insertedText.length - (editEnd - editStart));
    final region = newText.substring(regionStart, regionEnd);

    // 3. Re-parse only the affected region
    final newBlocks = _parseRegion(region, regionStart);

    // 4. Splice new blocks into the document, adjusting offsets for subsequent blocks
    final delta = newText.length - oldText.length;
    return _spliceBlocks(affectedStart, affectedEnd, newBlocks, delta);
  }
}
```

### Block Boundary Detection

Blocks are separated by blank lines or specific syntax boundaries (code fences, headings, etc.). The incremental engine detects block boundaries by scanning for:

- Blank lines (`\n\n`)
- Lines starting with `#`, `>`, `-`, `*`, `+`, digits followed by `.` or `)`, `` ` `` (triple), `~` (triple)
- Code fence open/close pairs

When an edit falls entirely within a single block and does not introduce or remove block boundary characters, only that one block is re-parsed.

---

## Editing Behavior: Reveal/Hide Mechanic

### Rules

1. **Block-level reveal:** A block is "active" when the cursor (or selection) is anywhere within that block's source range (using `Token.start` / `Token.stop`). Active blocks show raw markdown syntax. Inactive blocks are rendered.

2. **Inline-level reveal (within active block):** When the cursor is inside an inline element's `Token` range within the active block, the syntax delimiters for that specific inline are visible (e.g., `**` around bold text). Other inlines in the same block remain rendered.

3. **Transitions:**
   - Cursor enters a block → parse raw source, show syntax, position cursor correctly.
   - Cursor leaves a block → re-parse, collapse syntax, render visually.
   - Transition must be smooth (no visible flicker or layout jump).

4. **Special cases:**
   - **Headings:** When active, show `## Heading`. When inactive, render as styled large text without `##`.
   - **Code blocks:** When active, show `` ``` `` fences. When inactive, render as a styled code container. Content inside is always monospaced.
   - **Lists:** When active, show `- ` or `1. ` prefixes. When inactive, render with bullet/number glyphs and indentation.
   - **Links:** When active, show `[text](url)`. When inactive, show styled link text only.
   - **Images:** When active, show `![alt](url)`. When inactive, render the actual image (or placeholder if loading/error).
   - **Blockquotes:** When active, show `> ` prefix. When inactive, render with left border styling.
   - **Tables:** When active, show pipe-delimited raw syntax. When inactive, render as a formatted table widget.
   - **Thematic breaks:** When active, show `---`. When inactive, render as a horizontal divider.
   - **Math blocks:** When active, show `$$ ... $$`. When inactive, render the math expression (via a math rendering package).

### Cursor Position Mapping

When transitioning between revealed and collapsed states, the cursor position must be remapped:

```
Revealed:  "This is **bold** text"
           Position: 15 (inside "bold")
                         ^

Collapsed: "This is bold text"
           Position: 12 (inside "bold" — offset adjusted)
                        ^
```

Implement bidirectional mapping functions using the AST node's `Token` metadata:

```dart
class CursorMapper {
  /// Map a cursor offset in the full source (with syntax) to the rendered offset (without syntax).
  int revealedToCollapsed(int offset, MarkdownBlock block) {
    var adjustment = 0;
    for (final inline in block.children) {
      if (inline.sourceStart >= offset) break;
      if (inline is BoldInline) {
        // Subtract delimiter lengths that appear before cursor
        if (offset > inline.sourceStart) {
          adjustment += inline.delimiter.length; // opening delimiter
        }
        if (offset > inline.sourceStop - inline.delimiter.length) {
          adjustment += inline.delimiter.length; // closing delimiter
        }
      }
      // ... similar logic for other inline types with delimiters
    }
    return offset - adjustment;
  }

  /// Map a cursor offset in the rendered text back to the source offset.
  int collapsedToRevealed(int offset, MarkdownBlock block) {
    // Inverse of the above
  }
}
```

---

## TextSpan Tree Construction

### `MarkdownEditingController.buildTextSpan()`

This is the core rendering function. Override `TextEditingController.buildTextSpan()`:

```dart
class MarkdownEditingController extends TextEditingController {
  MarkdownDocument _document;
  final IncrementalParseEngine _parseEngine;
  final MarkdownRenderEngine _renderEngine;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final cursorOffset = selection.baseOffset;
    final activeBlockIndex = _document.blockIndexAtOffset(cursorOffset);
    final spans = <InlineSpan>[];

    for (var i = 0; i < _document.blocks.length; i++) {
      final block = _document.blocks[i];
      final isActive = (i == activeBlockIndex);

      if (isActive) {
        // Revealed mode: show raw syntax with syntax highlighting
        spans.add(_renderEngine.buildRevealedSpan(block, cursorOffset, style));
      } else {
        // Collapsed mode: render formatted output
        spans.add(_renderEngine.buildCollapsedSpan(block, style));
      }
    }

    return TextSpan(children: spans, style: style);
  }

  @override
  set value(TextEditingValue newValue) {
    // Intercept edits, run incremental parse, update _document
    if (newValue.text != text) {
      _document = _parseEngine.reparse(
        oldText: text,
        newText: newValue.text,
        editStart: _computeEditStart(text, newValue.text),
        editEnd: _computeEditEnd(text, newValue.text),
        insertedText: _computeInsertedText(text, newValue.text),
      );
    }
    super.value = newValue;
  }
}
```

### Styling for Rendered (Collapsed) Elements

| Element | Rendered Style |
|---|---|
| `# Heading 1` | fontSize: 2.0em, fontWeight: bold |
| `## Heading 2` | fontSize: 1.5em, fontWeight: bold |
| `### Heading 3` | fontSize: 1.25em, fontWeight: bold |
| `#### Heading 4` | fontSize: 1.1em, fontWeight: bold |
| `##### Heading 5` | fontSize: 1.0em, fontWeight: bold |
| `###### Heading 6` | fontSize: 0.9em, fontWeight: bold, color: muted |
| **bold** | fontWeight: bold |
| *italic* | fontStyle: italic |
| ***bold italic*** | fontWeight: bold, fontStyle: italic |
| `code` | fontFamily: monospace, backgroundColor: codeBg |
| ~~strikethrough~~ | decoration: lineThrough |
| [link](url) | color: linkColor, decoration: underline |
| ==highlight== | backgroundColor: highlightColor |
| > blockquote | Left border, italic, muted color |
| `---` | WidgetSpan with Divider |
| Code block | Full-width container, monospace, background color |
| Table | WidgetSpan with Table widget |
| Image | WidgetSpan with Image widget |

### Syntax Highlighting (Revealed Mode)

When a block is active and syntax is revealed, style the syntax delimiters differently from content:

```dart
class MarkdownRenderEngine {
  TextSpan buildRevealedSpan(MarkdownBlock block, int cursorOffset, TextStyle? baseStyle) {
    // For the active block, render the full source text with syntax highlighting
    final children = <TextSpan>[];

    for (final inline in block.children) {
      if (inline is BoldInline) {
        // Opening delimiter — muted style
        children.add(TextSpan(
          text: inline.delimiter,
          style: baseStyle?.merge(theme.syntaxDelimiterStyle),
        ));
        // Content — bold style
        children.addAll(_buildInlineSpans(inline.children, baseStyle?.merge(theme.boldStyle)));
        // Closing delimiter — muted style
        children.add(TextSpan(
          text: inline.delimiter,
          style: baseStyle?.merge(theme.syntaxDelimiterStyle),
        ));
      }
      // ... similar for other inline types
    }

    return TextSpan(children: children);
  }

  TextSpan buildCollapsedSpan(MarkdownBlock block, TextStyle? baseStyle) {
    // For inactive blocks, render only content without syntax characters
    if (block is HeadingBlock) {
      return TextSpan(
        text: block.children.map((i) => _inlineToPlainText(i)).join(),
        style: baseStyle?.merge(theme.headingStyles[block.level - 1]),
      );
    }
    // ... similar for other block types
  }
}
```

---

## WidgetSpan Usage for Complex Elements

Some elements cannot be represented as `TextSpan` alone. Use `WidgetSpan` for:

1. **Images** (`![alt](url)`) — render actual `Image` widget in collapsed mode.
2. **Thematic breaks** (`---`) — render as `Divider` widget.
3. **Tables** — render as a `Table` widget in collapsed mode.
4. **Code blocks** — render as a styled `Container` with syntax-highlighted code.
5. **Checkboxes** (`- [x]`, `- [ ]`) — render interactive `Checkbox` widgets.
6. **Math expressions** — render via math rendering widget.

**Important:** `WidgetSpan` has limitations within `EditableText`. Consider using a hybrid approach: a `Column` of widgets where each block is its own `EditableText` or widget, connected by a shared controller. This is the approach Typora itself uses internally (block-level separation).

---

## Alternative Architecture: Block-Level Widgets (v2)

Given the complexity of `WidgetSpan` within a single `EditableText`, the v2 architecture uses block-level separation:

```
MarkdownEditor
├── ListView.builder (or Column inside SingleChildScrollView)
│   ├── ParagraphBlockWidget (EditableText-based)
│   ├── HeadingBlockWidget (EditableText-based, larger font)
│   ├── CodeBlockWidget (custom widget with syntax highlighting)
│   ├── ImageBlockWidget (Image widget + caption EditableText)
│   ├── TableBlockWidget (Table widget, cells are EditableText)
│   ├── ListBlockWidget (Column of ListItemBlockWidget)
│   ├── BlockquoteBlockWidget (styled container with EditableText)
│   └── ThematicBreakBlockWidget (Divider widget)
```

### Cross-Block Editing

If using block-level widgets, implement a **FocusTraversalPolicy** and **cross-block selection**:

- Arrow keys at the end of one block move focus to the next block.
- Backspace at the start of a block merges with the previous block.
- Enter at the end of certain blocks (e.g., list item) creates a new block of the same type.
- Selection can span multiple blocks (multi-block selection).
- Cut/copy/paste operations work across block boundaries.

This is significantly more complex but enables richer rendering (tables, images, math, embeds).

---

## Keyboard Shortcuts & Input Handling

### Standard Shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl/Cmd + B` | Toggle bold (`**`) around selection |
| `Ctrl/Cmd + I` | Toggle italic (`*`) around selection |
| `Ctrl/Cmd + K` | Insert link `[](url)` or wrap selection `[selection](url)` |
| `Ctrl/Cmd + `` ` `` ` | Toggle inline code |
| `Ctrl/Cmd + Shift + K` | Toggle strikethrough (`~~`) |
| `Ctrl/Cmd + Shift + M` | Toggle inline math (if enabled) |
| `Ctrl/Cmd + 1..6` | Set heading level 1-6 for current line |
| `Ctrl/Cmd + 0` | Clear heading (convert to paragraph) |
| `Ctrl/Cmd + Shift + [` | Decrease indent (outdent list) |
| `Ctrl/Cmd + Shift + ]` | Increase indent (indent list) |
| `Ctrl/Cmd + Z` | Undo |
| `Ctrl/Cmd + Shift + Z` (or `Ctrl/Cmd + Y`) | Redo |
| `Ctrl/Cmd + S` | Save (triggers `onSaved` callback) |
| `Tab` | Indent list item (when cursor is in a list) |
| `Shift + Tab` | Outdent list item |
| `Enter` | Context-aware: new list item, exit code block (double enter), new paragraph |
| `Backspace` | Context-aware: unindent list, remove block prefix, merge blocks |
| `Ctrl/Cmd + Shift + C` | Toggle fenced code block |

### Auto-Completion / Continuation

| Trigger | Behavior |
|---|---|
| `Enter` in a list item | Create new list item with same prefix (`- `, `1. `) with auto-incremented number |
| `Enter` on empty list item | Exit list, convert to paragraph |
| `Enter` in blockquote | Continue blockquote prefix (`> `) |
| `Enter` on empty blockquote line | Exit blockquote |
| `Enter` in code block | New line within code block |
| `Enter` `Enter` at end of code block | Close code block, new paragraph |
| `` ``` `` + language + `Enter` | Open fenced code block |
| `---` + `Enter` on empty line | Insert thematic break |
| `> ` at start of line | Convert to blockquote |
| `# ` at start of line | Convert to heading (up to `######`) |
| `- ` or `* ` at start of line | Convert to unordered list item |
| `1. ` at start of line | Convert to ordered list item |
| `- [ ] ` at start of line | Convert to task list item |
| `\| ` at start of line | Begin table row |

### Smart Pair Completion

| Input | Auto-completes to | Condition |
|---|---|---|
| `**` | `****` (cursor between) | No existing bold context |
| `*` | `**` (cursor between) | No existing italic context |
| `` ` `` | ` `` ` ` (cursor between) | No existing code context |
| `~~` | `~~~~` (cursor between) | No existing strikethrough context |
| `[` | `[]()` (cursor in brackets) | When followed by space or EOL |
| `![` | `![]()` (cursor in brackets) | When followed by space or EOL |

---

## Undo / Redo

```dart
class UndoRedoManager {
  final List<MarkdownSnapshot> _undoStack = [];
  final List<MarkdownSnapshot> _redoStack = [];
  Timer? _coalesceTimer;
  static const _coalesceDelay = Duration(milliseconds: 1000);

  /// Record a change. Rapid edits within _coalesceDelay are merged into one entry.
  void recordChange(String markdown, TextSelection selection) {
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_coalesceDelay, () {
      _undoStack.add(MarkdownSnapshot(
        markdown: markdown,
        selection: selection,
        timestamp: DateTime.now(),
      ));
      _redoStack.clear(); // new edit invalidates redo stack
    });
  }

  /// Force-break the current coalescing group.
  /// Call on: whitespace, deletion, paste, format toggle, cursor jump.
  void breakGroup() {
    _coalesceTimer?.cancel();
    // Commit any pending coalesced edit immediately
  }

  MarkdownSnapshot? undo() {
    if (_undoStack.isEmpty) return null;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    return _undoStack.lastOrNull;
  }

  MarkdownSnapshot? redo() {
    if (_redoStack.isEmpty) return null;
    final snapshot = _redoStack.removeLast();
    _undoStack.add(snapshot);
    return snapshot;
  }

  bool get canUndo => _undoStack.length > 1;
  bool get canRedo => _redoStack.isNotEmpty;
}

class MarkdownSnapshot {
  final String markdown;
  final TextSelection selection;
  final DateTime timestamp;

  const MarkdownSnapshot({
    required this.markdown,
    required this.selection,
    required this.timestamp,
  });
}
```

**Coalescing rules:** Break undo groups on: whitespace insertion, deletion (backspace/delete), paste, formatting toggle, cursor jump (click or arrow key to non-adjacent position), or 1-second pause.

---

## Markdown Specification Support

### Required (Phase 1-2): CommonMark 0.31+

- Paragraphs
- ATX headings (`#` through `######`)
- Setext headings (`===` and `---` underlines)
- Fenced code blocks (`` ``` `` and `~~~`, with language info string)
- Indented code blocks
- Block quotes (`>`, nested)
- Ordered lists (`1.`, with start number)
- Unordered lists (`-`, `*`, `+`)
- Thematic breaks (`---`, `***`, `___`)
- Bold (`**` and `__`)
- Italic (`*` and `_`)
- Bold + italic (`***`)
- Inline code (`` ` `` and ``` `` ```)
- Links `[text](url "title")`
- Images `![alt](url "title")`
- Autolinks `<url>`
- Hard line breaks (trailing `  ` or `\`)
- Soft line breaks
- Backslash escapes
- HTML entities

### Required (Phase 2): GFM Extensions

- Tables (pipe syntax with alignment)
- Strikethrough (`~~text~~`)
- Task list items (`- [x]` / `- [ ]`)
- Autolinks (bare URLs and emails)

### Optional Extensions (Phase 4+)

- Footnotes (`[^ref]` and `[^ref]: definition`)
- Highlight (`==text==`)
- Subscript (`~text~`)
- Superscript (`^text^`)
- Math: inline `$expr$` and block `$$expr$$`
- Emoji shortcodes (`:smile:`)
- Table of contents (`[TOC]`)
- YAML front matter (`---` delimited)
- Definition lists
- Abbreviations
- Custom containers / admonitions

---

## Serialization & Roundtrip Fidelity

### Critical Requirement: Lossless Roundtrip

The editor MUST preserve the exact markdown source when no edits are made. Specifically:

- Whitespace, indentation, and line endings are preserved (Token `input` is used directly).
- Choice of `*` vs `_` for emphasis is preserved (stored in `delimiter` field).
- Choice of `-` vs `*` vs `+` for unordered lists is preserved (stored in `marker` field).
- Heading style (ATX vs Setext) is preserved (separate AST node types).
- Blank lines between blocks are preserved (`BlankLineBlock` nodes).
- Code fence style (`` ``` `` vs `~~~`) is preserved (stored in `fence` field).
- Link reference definitions are preserved.
- HTML blocks/inlines are preserved as-is.

When the user makes edits, only the affected region changes. The editor does not reformat the entire document.

### Normalization (Optional, User-Triggered)

Provide an optional `normalize()` method that standardizes the markdown (e.g., consistent heading style, list markers, blank lines). This is never called automatically.

---

## Public API

### `MarkdownEditor` Widget

```dart
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    this.initialMarkdown = '',
    this.controller,
    this.onChanged,
    this.onSaved,
    this.focusNode,
    this.theme,
    this.config,
    this.readOnly = false,
    this.autofocus = false,
    this.scrollController,
    this.scrollPhysics,
    this.minLines,
    this.maxLines,
    this.padding = const EdgeInsets.all(16.0),
    this.placeholder,
    this.toolbarBuilder,
    this.contextMenuBuilder,
    this.onImageInsert,
    this.onLinkTap,
  });

  /// Initial markdown content.
  final String initialMarkdown;

  /// Optional external controller for programmatic access.
  final MarkdownEditingController? controller;

  /// Called whenever the markdown content changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user triggers a save action (Cmd+S).
  final ValueChanged<String>? onSaved;

  /// Focus node for this editor.
  final FocusNode? focusNode;

  /// Visual theme for the editor.
  final MarkdownEditorTheme? theme;

  /// Feature configuration (enabled syntax, shortcuts, etc.).
  final MarkdownEditorConfig? config;

  /// Whether the editor is read-only (rendered, non-editable).
  final bool readOnly;

  /// Whether the editor should autofocus on mount.
  final bool autofocus;

  /// Scroll controller.
  final ScrollController? scrollController;

  /// Scroll physics.
  final ScrollPhysics? scrollPhysics;

  /// Min/max visible lines.
  final int? minLines;
  final int? maxLines;

  /// Padding around the editor content.
  final EdgeInsets padding;

  /// Placeholder text shown when editor is empty.
  final String? placeholder;

  /// Builder for a toolbar widget (receives editor state for toggling).
  final Widget Function(BuildContext, MarkdownEditorState)? toolbarBuilder;

  /// Builder for the context menu (right-click / long-press).
  final Widget Function(BuildContext, EditableTextState)? contextMenuBuilder;

  /// Callback when the user inserts an image (for custom upload handling).
  /// Return the URL/path to use, or null to cancel.
  final Future<String?> Function(ImageInsertEvent)? onImageInsert;

  /// Callback when the user taps a link in read-only or rendered mode.
  final void Function(String url)? onLinkTap;
}
```

### `MarkdownEditingController`

```dart
class MarkdownEditingController extends TextEditingController {
  /// Current markdown content.
  String get markdown;
  set markdown(String value);

  /// Parsed document AST (read-only view).
  MarkdownDocument get document;

  // ─── Inline Format Toggles ───

  /// Toggle bold (`**`) around selection. If no selection, inserts `****` with cursor between.
  void toggleBold();

  /// Toggle italic (`*`) around selection.
  void toggleItalic();

  /// Toggle strikethrough (`~~`) around selection.
  void toggleStrikethrough();

  /// Toggle inline code (`` ` ``) around selection.
  void toggleInlineCode();

  /// Toggle inline math (`$`) around selection (if enabled in config).
  void toggleInlineMath();

  /// Toggle highlight (`==`) around selection (if enabled in config).
  void toggleHighlight();

  // ─── Block Type Setters ───

  /// Set heading level for the current line/block. 0 = paragraph, 1-6 = heading.
  void setHeadingLevel(int level);

  /// Toggle blockquote prefix for the current block.
  void toggleBlockquote();

  /// Toggle unordered list for the current block.
  void toggleUnorderedList();

  /// Toggle ordered list for the current block.
  void toggleOrderedList();

  /// Toggle task list for the current block.
  void toggleTaskList();

  /// Insert a fenced code block at the cursor position.
  void insertCodeBlock({String language = ''});

  /// Insert a thematic break at the cursor position.
  void insertThematicBreak();

  /// Insert a table at the cursor position.
  void insertTable({int rows = 3, int cols = 3});

  // ─── Content Insertion ───

  /// Insert a link. If text is selected, wraps it: `[selection](url)`.
  void insertLink(String text, String url);

  /// Insert an image reference.
  void insertImage(String alt, String url);

  /// Insert raw text at the cursor position.
  void insertText(String text);

  // ─── Indentation ───

  /// Indent the current block (for lists: add nesting level, for blockquotes: add `>`).
  void indent();

  /// Outdent the current block.
  void outdent();

  // ─── Undo / Redo ───

  void undo();
  void redo();
  bool get canUndo;
  bool get canRedo;

  // ─── Cursor Context Info ───

  /// The set of inline formats active at the cursor position.
  /// Useful for toolbar button state (pressed/unpressed).
  Set<InlineType> get activeInlineFormats;

  /// The block type of the block containing the cursor.
  BlockType get activeBlockType;

  /// The heading level at the cursor (0 if not a heading).
  int get activeHeadingLevel;

  /// Whether the cursor is inside a code block.
  bool get isInCodeBlock;

  /// Whether the cursor is inside a blockquote.
  bool get isInBlockquote;

  /// Whether the cursor is inside a list.
  bool get isInList;

  // ─── Export ───

  /// Serialize back to markdown string (lossless roundtrip).
  String toMarkdown();

  /// Convert to HTML string.
  String toHtml();

  /// Extract plain text (no syntax, no formatting).
  @override
  String get text; // already provided by TextEditingController
}
```

### `MarkdownEditorConfig`

```dart
class MarkdownEditorConfig {
  /// Which markdown extensions to enable beyond CommonMark.
  final Set<MarkdownExtension> enabledExtensions;

  /// Whether to show line numbers in code blocks.
  final bool codeBlockLineNumbers;

  /// Whether to enable smart pair completion (auto-close `**`, `` ` ``, etc.).
  final bool smartPairCompletion;

  /// Whether to enable auto-continuation of lists and blockquotes on Enter.
  final bool autoContinuation;

  /// Whether to enable drag-and-drop image insertion.
  final bool enableImageDragDrop;

  /// Whether to enable paste of HTML content converted to markdown.
  final bool enableHtmlPaste;

  /// Custom keyboard shortcut overrides.
  final Map<ShortcutActivator, MarkdownEditorAction>? shortcutOverrides;

  /// Maximum image width for rendered images (in logical pixels).
  final double maxImageWidth;

  /// Placeholder text for empty editor.
  final String? placeholder;

  const MarkdownEditorConfig({
    this.enabledExtensions = const {
      MarkdownExtension.tables,
      MarkdownExtension.strikethrough,
      MarkdownExtension.taskLists,
      MarkdownExtension.autolinks,
    },
    this.codeBlockLineNumbers = true,
    this.smartPairCompletion = true,
    this.autoContinuation = true,
    this.enableImageDragDrop = true,
    this.enableHtmlPaste = true,
    this.shortcutOverrides,
    this.maxImageWidth = 600.0,
    this.placeholder,
  });
}

enum MarkdownExtension {
  tables,
  strikethrough,
  taskLists,
  autolinks,
  footnotes,
  highlight,
  subscript,
  superscript,
  math,
  emoji,
  tableOfContents,
  yamlFrontMatter,
  definitionLists,
}

enum MarkdownEditorAction {
  toggleBold,
  toggleItalic,
  toggleStrikethrough,
  toggleInlineCode,
  toggleInlineMath,
  toggleHighlight,
  setHeading1,
  setHeading2,
  setHeading3,
  setHeading4,
  setHeading5,
  setHeading6,
  clearHeading,
  toggleBlockquote,
  toggleUnorderedList,
  toggleOrderedList,
  toggleTaskList,
  insertCodeBlock,
  insertThematicBreak,
  insertLink,
  insertImage,
  indent,
  outdent,
  undo,
  redo,
  save,
}
```

### `MarkdownEditorTheme`

```dart
class MarkdownEditorTheme {
  /// Base text style for the editor.
  final TextStyle baseStyle;

  /// Heading styles (index 0 = H1, index 5 = H6).
  final List<TextStyle> headingStyles;

  /// Inline formatting styles.
  final TextStyle boldStyle;
  final TextStyle italicStyle;
  final TextStyle inlineCodeStyle;
  final TextStyle strikethroughStyle;
  final TextStyle linkStyle;
  final TextStyle highlightStyle;

  /// Code block styling.
  final TextStyle codeBlockStyle;
  final Color codeBlockBackground;
  final double codeBlockBorderRadius;
  final Color codeBlockBorderColor;

  /// Blockquote styling.
  final Color blockquoteBorderColor;
  final double blockquoteBorderWidth;
  final TextStyle blockquoteStyle;
  final Color blockquoteBackground;

  /// Syntax highlighting (revealed mode — syntax delimiters like **, `, #).
  final TextStyle syntaxDelimiterStyle;

  /// Thematic break styling.
  final Color thematicBreakColor;
  final double thematicBreakThickness;

  /// Table styling.
  final TextStyle tableHeaderStyle;
  final Color tableBorderColor;
  final Color tableHeaderBackground;
  final Color tableAlternateRowBackground;

  /// Selection and cursor.
  final Color cursorColor;
  final Color selectionColor;
  final double cursorWidth;

  /// Placeholder text style.
  final TextStyle placeholderStyle;

  /// Editor background color.
  final Color backgroundColor;

  /// Predefined themes.
  static MarkdownEditorTheme light() => MarkdownEditorTheme(/* ... */);
  static MarkdownEditorTheme dark() => MarkdownEditorTheme(/* ... */);
  static MarkdownEditorTheme sepia() => MarkdownEditorTheme(/* ... */);

  /// Create a theme by merging overrides onto a base theme.
  MarkdownEditorTheme copyWith({/* all fields optional */});
}
```

### `ImageInsertEvent`

```dart
class ImageInsertEvent {
  /// The source of the image insertion.
  final ImageInsertSource source;

  /// Raw bytes of the image (for drag-drop and paste).
  final Uint8List? bytes;

  /// File path (for file picker).
  final String? filePath;

  /// MIME type if known.
  final String? mimeType;

  const ImageInsertEvent({
    required this.source,
    this.bytes,
    this.filePath,
    this.mimeType,
  });
}

enum ImageInsertSource {
  dragDrop,
  paste,
  filePicker,
  toolbar,
}
```

---

## Implementation Phases

### Phase 1: Foundation — Parser & Core Rendering ✅ COMPLETE

**Goal:** A working editor that can parse basic markdown and render it with the reveal/hide mechanic. No toolbar, no complex blocks.

**PetitParser Grammar (subset):**
- [x] Set up PetitParser dependency and `MarkdownGrammarDefinition` skeleton
- [x] Block productions: `paragraph`, `atxHeading`, `blankLine`, `thematicBreak`
- [x] Inline productions: `plainText`, `bold`, `italic`, `boldItalic`, `inlineCode`, `escapedChar`
- [x] `MarkdownParserDefinition` with `.token().map()` overrides for all above productions
- [x] Validate grammar with PetitParser `linter()`
- [x] Test individual productions with `definition.buildFrom()`

**AST & Document Model:**
- [x] `MarkdownNode` base class with `Token` metadata
- [x] Block nodes: `ParagraphBlock`, `HeadingBlock`, `BlankLineBlock`, `ThematicBreakBlock`
- [x] Inline nodes: `PlainTextInline`, `BoldInline`, `ItalicInline`, `BoldItalicInline`, `InlineCodeInline`, `EscapedCharInline`
- [x] `MarkdownDocument` with `blockIndexAtOffset()` and `inlineAtOffset()`
- [x] Serialization: `toMarkdown()` using `Token.input` for lossless roundtrip

**Controller & Rendering:**
- [x] `MarkdownEditingController` extending `TextEditingController`
- [x] Override `buildTextSpan()` with active block detection
- [x] `MarkdownRenderEngine.buildRevealedSpan()` — syntax-highlighted raw source
- [x] `MarkdownRenderEngine.buildCollapsedSpan()` — rendered styled text
- [x] `CursorMapper` — delimiter range detection and snap-to-content

**Editor Widget:**
- [x] `MarkdownEditor` stateful widget wrapping `EditableText`
- [x] Basic cursor tracking to determine active block
- [x] Reveal/hide transitions via hidden syntax style (fontSize: 0.01, transparent)

**Infrastructure:**
- [x] `MarkdownEditorTheme` with `light()` and `dark()` presets
- [x] `UndoRedoManager` with coalescing (1-second timer, max 200 stack)
- [x] Unit tests: 541 tests passing (parser, nodes, rendering, controller, widget, undo/redo, formatting, shortcuts, smart editing)
- [x] Example app: `example/editor_demo.dart` with undo/redo dropdown history toolbar
- [x] Named undo/redo snapshots with auto-generated descriptions and multi-step jump
- [x] Text selection via `TextSelectionGestureDetectorBuilder` (click, drag, double-click)

**Acceptance criteria:** All met.
- `parse(source).toMarkdown() == source` verified for all constructs
- Headings render large when collapsed, `##` visible when revealed
- Bold/italic/code styled when collapsed, delimiters visible when revealed
- Undo/redo works with coalescing

---

### Phase 2: Full CommonMark + GFM Syntax — ✅ COMPLETE (text rendering; WidgetSpan deferred to Phase 4)

**Goal:** Support all CommonMark and GFM syntax. Complex block rendering via WidgetSpan.

**PetitParser Grammar (additions):**
- [x] Block productions: `fencedCodeBlock`, `blockquote`, `unorderedListItem`, `orderedListItem`, `table` (GFM pipes), `setextHeading` — (`indentedCodeBlock` deferred, `blockquote` single-line only)
- [x] Inline productions: `link`, `image`, `autolink`, `strikethrough` (Phase 1), `taskCheckbox` — (`hardLineBreak` deferred to Phase 3)
- [x] Helper productions: `listIndent`, `infoString`, `codeBlockContent`, `linkUrl`, `linkTitle`, `tableRow`, `tableDelimiter`, `taskCheckbox`, `openFence`, `closeFence`
- [x] Update `MarkdownParserDefinition` with `.token().map()` for all new productions

**AST Nodes (additions):**
- [x] Block nodes: `FencedCodeBlock`, `BlockquoteBlock`, `UnorderedListItemBlock`, `OrderedListItemBlock`, `TableBlock`, `SetextHeadingBlock` — (`IndentedCodeBlock` deferred)
- [x] Inline nodes: `LinkInline`, `ImageInline`, `AutolinkInline`, `StrikethroughInline` (Phase 1) — (`HardLineBreakInline` deferred)
- [x] Table support types: `TableRow`, `TableCell`, `TableAlignment`

**Incremental Parsing:** *(deferred — full re-parse is fast enough for current scope)*
- [ ] `IncrementalParseEngine` — detect affected blocks on edit, re-parse only those
- [ ] Block boundary detection (blank lines, fence markers, heading markers)
- [ ] Offset adjustment for blocks after the edit region

**Rendering (additions):**
- [x] Code blocks: monospace container with `codeBlockStyle` — (syntax highlighting deferred)
- [x] Blockquotes: styled with `blockquoteStyle` — (left-border `WidgetSpan` deferred to Phase 4)
- [x] Lists: marker prefix reveal/hide with inline content rendering
- [x] Links: styled text with `linkStyle`
- [x] Strikethrough: `TextDecoration.lineThrough` (Phase 1)
- [x] Setext headings: underline delimiter styling
- [x] Images: alt text display (actual `Image` widget deferred to Phase 4)
- [x] Tables: monospace text rendering (actual `Table` widget deferred to Phase 4)

**Deferred to Phase 4 (WidgetSpan rendering):**
- [ ] Code block syntax highlighting with language detection from info string
- [ ] Task lists: interactive checkbox `WidgetSpan`
- [ ] Tables: `Table` widget via `WidgetSpan`
- [ ] Images: `Image.network` / `Image.file` via `WidgetSpan`
- [ ] Thematic breaks: `Divider` via `WidgetSpan`
- [ ] Blockquotes: left-border via `WidgetSpan`

**Testing:**
- [ ] CommonMark spec test suite integration (parse each spec example, verify output)
- [x] GFM table parsing edge cases (alignment markers, header/body rows, cell splitting)
- [x] Code block with backtick/tilde fences, optional info string
- [ ] Nested blockquotes and lists — (nesting deferred; single-line blocks only)

**Acceptance criteria (updated for text-rendering scope):**
- [x] All Phase 2 block/inline types parse correctly with lossless roundtrip
- [x] Code blocks render as monospace, blockquotes as styled text, lists with markers
- [x] Links styled with linkStyle, images show alt text, tables show monospace source
- [ ] CommonMark spec test suite — deferred
- [ ] WidgetSpan rendering (tables, images, checkboxes, dividers) — deferred to Phase 4

---

### Phase 3: Editing UX & Keyboard Shortcuts

**Goal:** Full keyboard-driven editing experience matching Typora's behavior.

#### Phase 3a: Inline Format Toggles + Keyboard Shortcuts — ✅ COMPLETE

**Controller format toggle methods:**
- [x] `toggleBold()` — wrap/unwrap `**` around selection, insert empty pair at collapsed cursor
- [x] `toggleItalic()` — wrap/unwrap `*` around selection
- [x] `toggleInlineCode()` — wrap/unwrap `` ` `` around selection
- [x] `toggleStrikethrough()` — wrap/unwrap `~~` around selection
- [x] `setHeadingLevel(int)` — set/toggle heading prefix on current line (0=paragraph, 1–6)
- [x] `_toggleInlineDelimiter(String)` — shared helper for all inline format toggles

**Keyboard shortcut infrastructure:**
- [x] `Shortcuts` + `Actions` widget wrapping `EditableText`
- [x] `Intent` subclasses for all actions (formatting, headings, undo/redo)
- [x] Platform-aware modifier keys (Cmd on macOS, Ctrl on others)

**Keyboard Shortcuts (implemented):**
- [x] `Ctrl/Cmd + B` — toggle bold
- [x] `Ctrl/Cmd + I` — toggle italic
- [x] `Ctrl/Cmd + `` ` `` ` — toggle inline code
- [x] `Ctrl/Cmd + Shift + K` — toggle strikethrough
- [x] `Ctrl/Cmd + 1..6` — set heading level
- [x] `Ctrl/Cmd + 0` — clear heading
- [x] `Ctrl/Cmd + Z` / `Ctrl/Cmd + Shift + Z` — undo/redo

**Example toolbar:**
- [x] Bold, italic, code, strikethrough `IconButton` widgets
- [x] Split undo/redo buttons (click for single step, dropdown for history)

**Testing:** 34 new tests (20 formatting commands + 14 shortcut/widget tests), 412 total passing.

#### Phase 3b: Smart Enter/Backspace ✅ COMPLETE

**Approach:** `TextInputFormatter` — intercepts text input changes inside `EditableText` before they reach the controller, avoiding the double-handling race condition between key events and text input deltas.

**Smart Enter Behavior:**
- [x] `Enter` in list item → new list item with same marker (auto-increment for ordered)
- [x] `Enter` on empty list item → exit list, remove prefix
- [x] `Enter` in blockquote → continue with `> ` prefix
- [x] `Enter` on empty blockquote → exit blockquote
- [x] `Enter` after heading → plain newline (no continuation)
- [x] `Enter` in task list → continue with `- [ ] ` (always unchecked)
- [x] `Enter` mid-line → splits content with prefix on new line
- [x] `Enter` in normal paragraph → pass-through (default behaviour)

**Smart Backspace Behavior:**
- [x] `Backspace` at content start of list item → remove prefix, keep content
- [x] `Backspace` at content start of heading → remove heading prefix
- [x] `Backspace` at content start of blockquote → remove `>` prefix
- [x] `Backspace` elsewhere → pass-through (default behaviour)

**Implementation:**
- `applySmartEnter()` / `applySmartBackspace()` on `MarkdownEditingController` — pure text manipulation using line-level regex (no AST dependency)
- `_SmartEditFormatter extends TextInputFormatter` in widget — detects Enter/Backspace patterns, delegates to controller
- Formatter wired into `EditableText.inputFormatters`

**Testing:** 50 new tests (28 enter + 20 backspace + 2 widget integration), 462 total passing.

#### Phase 3c: Advanced Editing — ✅ COMPLETE

**Keyboard Shortcuts (remaining):**
- [x] `Ctrl/Cmd + K` — insert/wrap link
- [x] `Ctrl/Cmd + Shift + [` / `]` — outdent/indent
- [x] `Ctrl/Cmd + S` — save (triggers `onSaved` callback)
- [x] `Tab` / `Shift + Tab` — indent/outdent list items (via FocusNode onKeyEvent)
- [x] `Ctrl/Cmd + Shift + C` — toggle code block (wrap/unwrap ``` fences)

**Auto-Completion:**
- [x] Smart pair completion (`` ` ``, `**`, `~~`, `[`, `![`) — auto-close with cursor between; suppressed inside code blocks/inline code
- [x] Auto-detect markdown shortcuts at line start (`# `, `- `, `1. `, `> `, `---`, `` ``` ``) — parser already handles real-time reparse on text change

**Clipboard Handling:**
- [x] Cut/copy: copy raw markdown to clipboard (default EditableText behavior preserves raw markdown)
- [x] Paste plain text: insert as-is into current block (default EditableText behavior)
- [ ] Paste HTML: convert to markdown using an HTML-to-markdown converter — deferred to Phase 4
- [ ] Paste image: trigger `onImageInsert` callback, insert `![](url)` on result — deferred to Phase 4

**Multi-Block Selection:**
- [x] Selection spanning multiple blocks
- [x] Cut/copy/delete operations across block boundaries
- [x] Formatting operations on multi-block selections (e.g., bold all selected text)

**Context Menu:** — deferred to Phase 4
- [ ] Custom context menu with cut/copy/paste + formatting options
- [ ] Platform-native context menu integration

**Implementation:**
- `indent()` / `outdent()` on `MarkdownEditingController` — adds/removes 2-space prefix for list items
- `insertLink()` — collapsed: `[](url)`, selection: `[selection](url)` with cursor in `()`
- `toggleCodeBlock()` — wrap/unwrap ``` fences with code block detection
- `applySmartPairCompletion()` — auto-close pairs in `_SmartEditFormatter`
- `_isInsideCodeContext()` — helper to suppress pair completion in code
- `_handleTabKeyEvent` on `FocusNode.onKeyEvent` — intercepts Tab/Shift+Tab
- `onSaved` callback on `MarkdownEditor` widget
- `FilteringTextInputFormatter.deny(RegExp(r'\t'))` blocks platform \t injection

**Testing:** 71 new tests (formatting, shortcuts, smart pairs, auto-detect, clipboard, multi-block), 541 total passing.

**Acceptance criteria (updated):**
- [x] All keyboard shortcuts work (tested on macOS; Ctrl variants for Linux/Windows mapped)
- [x] Typing `# Hello` + Enter creates a heading and a new paragraph (via Phase 3b smart Enter)
- [x] Typing `- item 1` + Enter creates a second list item (via Phase 3b)
- [x] Pressing Enter on an empty `- ` exits the list (via Phase 3b)
- [ ] Pasting HTML from a web page produces clean markdown — deferred to Phase 4

---

### Phase 4: Toolbar, Extensions & Polish

**Goal:** Production-ready polish, optional extensions, toolbar, accessibility.

**Toolbar:**
- [x] `MarkdownToolbar` default widget with configurable buttons
- [x] Toolbar items: bold, italic, strikethrough, code, heading dropdown, list toggles, link, image, code block, table, thematic break
- [x] Toolbar button state reflects cursor context (`activeInlineFormats`, `activeBlockType`)
- [x] Mobile-friendly toolbar (compact, scrollable)
- [ ] Desktop-friendly toolbar (full-width, icon + text)
- [x] `toolbarBuilder` callback for fully custom toolbars

**Optional Extensions (Grammar Additions):**
- [ ] Math: inline `$expr$` and block `$$expr$$` — render via `flutter_math_fork`
- [ ] Footnotes: `[^ref]` and `[^ref]: definition` — render as superscript with popup
- [ ] Highlight: `==text==` — render with background color
- [ ] Emoji shortcodes: `:smile:` → 😄 — render as Unicode emoji
- [ ] YAML front matter: `---` delimited block — hidden or collapsible in editor
- [ ] Subscript `~text~` and superscript `^text^`
- [ ] Table of contents `[TOC]` — render as a dynamic list of headings
- [ ] Each extension is a separate PetitParser production, enabled/disabled via `MarkdownEditorConfig.enabledExtensions`

**Image Handling:**
- [ ] Drag-and-drop image insertion (desktop + web)
- [ ] Paste image from clipboard
- [ ] Image resize handles in rendered mode
- [ ] Image loading indicators and error states
- [ ] `onImageInsert` callback for custom upload workflows

**Performance Optimization:**
- [ ] Lazy span building — only build `TextSpan` for visible blocks (viewport + buffer)
- [ ] `TextPainter` result caching for unchanged blocks
- [ ] Debounced parsing for very rapid edits
- [ ] Profile and optimize for 10,000+ line documents
- [ ] Memory profiling and optimization

**Accessibility:**
- [ ] Screen reader support: semantic labels for headings, lists, links, images
- [ ] ARIA-equivalent attributes for web platform
- [ ] Keyboard navigation without mouse
- [ ] High-contrast theme variant
- [ ] Announce formatting changes to screen reader

**Additional Features:**
- [ ] Find and replace (`Ctrl/Cmd + F`, `Ctrl/Cmd + H`)
- [ ] Word count / character count / reading time
- [ ] Spell-check integration (platform-native)
- [ ] Export to HTML (`toHtml()` method)
- [ ] `readOnly` mode: fully rendered, non-editable, all blocks collapsed
- [ ] Sepia theme preset
- [ ] Smooth animations for reveal/hide transitions (optional, configurable duration)
- [ ] Code block copy button
- [ ] Link preview on hover (desktop)

**Platform Testing & Fixes:**
- [ ] iOS: selection handles, keyboard accessory bar, safe area
- [ ] Android: IME composition, context menu, back button
- [ ] macOS: native menu bar integration, trackpad gestures
- [ ] Windows: touch support, on-screen keyboard
- [ ] Linux: input method framework (IBus/Fcitx) compatibility
- [ ] Web: browser selection API, mobile browser quirks

**Testing:**
- [ ] Golden tests for rendered blocks (pixel-perfect regression)
- [ ] Performance benchmarks: 1K, 5K, 10K line documents
- [ ] Accessibility audit
- [ ] Platform-specific integration tests
- [ ] Fuzz testing: random edit sequences to catch parser crashes

**Acceptance criteria:**
- Toolbar reflects current cursor context and all buttons work.
- Math expressions render correctly (if extension enabled).
- Editor handles 10,000+ line documents at 60 FPS scrolling.
- Screen reader can navigate all block types.
- All 6 target platforms pass integration tests.

---

## Performance Targets

| Metric | Target |
|---|---|
| Initial full parse (1,000 lines) | < 50ms |
| Incremental parse (single line edit) | < 5ms |
| `buildTextSpan()` for visible content | < 8ms (within 16ms frame budget) |
| Memory for 10,000 line document | < 50MB |
| Scroll frame rate | 60 FPS |
| Time to interactive (cold start) | < 200ms |

### Optimization Strategies

- **Incremental parsing:** `IncrementalParseEngine` re-parses only affected blocks on each edit.
- **Lazy span building:** Only build `TextSpan` for blocks within the visible viewport (+ buffer above/below).
- **Text layout caching:** Cache `TextPainter` layout results for unchanged blocks; invalidate on edit or theme change.
- **Debounced full re-parse:** For very rapid edits (e.g., holding backspace), debounce full document re-parse while keeping cursor-local block up to date.
- **Isolate parsing (optional):** For initial parse of very large documents, run PetitParser in a separate isolate.

---

## Dependencies

| Package | Version | Purpose | Phase |
|---|---|---|---|
| `flutter` | SDK | Framework | 1 |
| `petitparser` | ^7.0.0 | Parser combinator for markdown grammar | 1 |
| `flutter_highlight` or `highlight` | latest | Syntax highlighting for code blocks | 2 |
| `url_launcher` | latest | Opening links in browser | 2 |
| `flutter_math_fork` | latest | Math expression rendering ($, $$) | 4 |
| `image_picker` | latest | Image insertion UI on mobile | 4 |
| `super_clipboard` | latest | Rich clipboard (HTML paste, image paste) | 3 |

**Note on parser choice:** We use PetitParser rather than the `markdown` or `dart_markdown` packages because those produce HTML output and do not provide the source range tracking (`Token` metadata) required for the reveal/hide mechanic. The CommonMark spec test suite should still be used to validate parsing correctness.

---

## File Structure

```
markdowner/
├── lib/
│   ├── markdowner.dart                          # Public API barrel export
│   ├── src/
│   │   ├── editor/
│   │   │   ├── markdown_editor.dart             # Main MarkdownEditor widget
│   │   │   ├── markdown_editor_state.dart       # State management
│   │   │   ├── markdown_editing_controller.dart # Controller with buildTextSpan()
│   │   │   └── markdown_editor_shortcuts.dart   # Keyboard shortcut bindings
│   │   ├── model/
│   │   │   ├── markdown_document.dart           # MarkdownDocument class
│   │   │   ├── markdown_block.dart              # Block-level AST nodes
│   │   │   ├── markdown_inline.dart             # Inline-level AST nodes
│   │   │   └── markdown_enums.dart              # BlockType, InlineType, etc.
│   │   ├── parser/
│   │   │   ├── markdown_grammar.dart            # MarkdownGrammarDefinition (PetitParser)
│   │   │   ├── markdown_parser.dart             # MarkdownParserDefinition (AST construction)
│   │   │   └── incremental_parser.dart          # IncrementalParseEngine
│   │   ├── render/
│   │   │   ├── render_engine.dart               # MarkdownRenderEngine
│   │   │   ├── block_renderers.dart             # Per-block-type rendering functions
│   │   │   ├── inline_renderers.dart            # Per-inline-type rendering functions
│   │   │   ├── syntax_highlight.dart            # Code block syntax highlighting
│   │   │   └── widget_spans.dart                # WidgetSpan builders (images, tables, etc.)
│   │   ├── theme/
│   │   │   ├── markdown_editor_theme.dart       # MarkdownEditorTheme class
│   │   │   └── default_themes.dart              # light(), dark(), sepia() presets
│   │   ├── config/
│   │   │   └── markdown_editor_config.dart      # MarkdownEditorConfig, enums
│   │   ├── toolbar/
│   │   │   ├── markdown_toolbar.dart            # Default toolbar widget
│   │   │   └── toolbar_items.dart               # Individual toolbar button widgets
│   │   └── utils/
│   │       ├── cursor_mapper.dart               # Revealed ↔ collapsed offset mapping
│   │       ├── undo_redo.dart                   # UndoRedoManager, MarkdownSnapshot
│   │       ├── clipboard_handler.dart           # Paste processing (HTML→MD, image)
│   │       ├── html_converter.dart              # Markdown → HTML export
│   │       └── markdown_serializer.dart         # AST → markdown string serialization
├── test/
│   ├── parser/
│   │   ├── grammar_test.dart                    # Test individual grammar productions
│   │   ├── parser_test.dart                     # Test AST construction
│   │   ├── incremental_parser_test.dart         # Test incremental re-parsing
│   │   └── commonmark_spec_test.dart            # CommonMark spec test suite
│   ├── model/
│   │   ├── roundtrip_test.dart                  # parse(x).toMarkdown() == x
│   │   └── document_test.dart                   # blockIndexAtOffset, inlineAtOffset
│   ├── editor/
│   │   ├── controller_test.dart                 # buildTextSpan, format toggles
│   │   ├── reveal_hide_test.dart                # Cursor-driven reveal/collapse
│   │   ├── shortcuts_test.dart                  # Keyboard shortcut widget tests
│   │   └── smart_edit_test.dart                 # Enter/Backspace/Tab behavior
│   ├── render/
│   │   ├── span_builder_test.dart               # Rendered TextSpan correctness
│   │   └── widget_span_test.dart                # WidgetSpan rendering (images, tables)
│   └── golden/
│       └── *.png                                # Golden image regression tests
├── example/
│   ├── lib/
│   │   └── main.dart                            # Example app demonstrating MarkdownEditor
│   └── pubspec.yaml
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
└── LICENSE
```

---

## Open Questions & Risks

1. **Single EditableText vs block-level widgets:** The single `EditableText` approach (Phase 1-3) is simpler but limits what can be rendered inline (no real images, interactive tables). The block-level approach (v2 architecture) is more powerful but requires implementing cross-block editing, selection, and focus management from scratch. **Recommendation:** Start with single `EditableText` for Phase 1-3, evaluate migration to block-level in Phase 4 based on WidgetSpan limitations encountered.

2. **WidgetSpan limitations:** `WidgetSpan` within `EditableText` has known issues on some platforms (inconsistent baseline alignment, selection behavior crossing widget boundaries). If these prove blocking, the block-level architecture becomes necessary earlier.

3. **PetitParser performance for markdown:** PEG parsers can have exponential backtracking on pathological inputs. Markdown's emphasis rules (left-flanking, right-flanking delimiter runs) are particularly tricky. Mitigation: use `.starLazy()` for greedy-reluctant balance, add explicit negative lookaheads, and test with adversarial inputs.

4. **CommonMark emphasis rules:** The CommonMark spec has very detailed rules for how `*` and `_` interact (rule 1-17 in the spec). PetitParser's PEG semantics (ordered choice, first match wins) may not perfectly match these rules without careful production ordering and negative lookaheads.

5. **IME compatibility:** Complex input methods (CJK, emoji pickers) interact with `TextEditingController` in non-trivial ways. Reveal/hide transitions must not break IME composing state. Test extensively with Japanese, Chinese, Korean input.

6. **Large document performance:** Incremental parsing and lazy rendering are essential. Without them, documents over ~1,000 lines will degrade. The `IncrementalParseEngine` is the critical optimization.

7. **Nested constructs:** Deeply nested markdown (blockquotes within lists within blockquotes) is complex to parse and render. PetitParser handles recursion naturally via `ref0()`, but the render engine must handle arbitrary nesting depth.

8. **Platform parity:** `EditableText` behavior differs across platforms (selection handles, context menus, keyboard shortcuts, IME behavior). Test on all 6 target platforms per phase.

9. **Roundtrip fidelity edge cases:** Some markdown constructs have multiple valid representations. The parser must preserve the original representation (using `Token.input`) rather than normalizing.