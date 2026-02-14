## 0.1.0 — 2026-02-14

Phase 1: Foundation — Parser & Core Rendering

* PetitParser-based markdown grammar and parser with AST construction
* Sealed class AST model with Token metadata for source position tracking
* Block nodes: paragraphs, ATX headings, thematic breaks, blank lines
* Inline nodes: bold, italic, bold-italic, inline code, strikethrough, escaped chars
* `MarkdownDocument.toMarkdown()` for lossless roundtrip serialization
* `MarkdownRenderEngine` with revealed/collapsed TextSpan tree building
* `MarkdownEditingController` extending `TextEditingController` with reveal/hide mechanic
* `MarkdownEditorTheme` with light and dark presets
* `CursorMapper` for delimiter range detection and snap-to-content
* `UndoRedoManager` with 1-second coalescing and max 200 stack size
* `MarkdownEditor` widget wrapping `EditableText`
* Example app with undo/redo toolbar
* 225 tests passing, zero analysis issues

## 0.0.1

* Initial project setup
