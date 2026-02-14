# Markdowner

A high-performance Flutter markdown WYSIWYG widget that provides a **Typora-style editing experience** built on top of `EditableText`.

Type markdown and see it rendered as rich text in real-time. When the cursor enters a block, raw syntax is revealed for editing. When the cursor leaves, syntax collapses and content renders visually.

## Status

**Phase 1 complete** — parser, AST, rendering engine, controller, and editor widget.

See [ROADMAP.md](ROADMAP.md) for the full specification and implementation phases.

## Features (Phase 1)

- **Reveal/hide WYSIWYG** — syntax visible when editing a block, collapsed when cursor leaves
- **PetitParser-based grammar** — composable, testable, extensible markdown parser
- **Lossless roundtrip** — `parse(source).toMarkdown() == source`
- **Light and dark themes** — with customizable styles via `MarkdownEditorTheme`
- **Undo/redo** — stack-based with 1-second coalescing

### Supported Syntax

| Block | Inline |
|---|---|
| ATX headings (`#` through `######`) | Bold (`**` and `__`) |
| Paragraphs | Italic (`*` and `_`) |
| Thematic breaks (`---`, `***`, `___`) | Bold-italic (`***`) |
| Blank lines | Inline code (`` ` `` and ``` `` ```) |
| | Strikethrough (`~~`) |
| | Escaped characters (`\*`, `\#`, etc.) |

## Getting Started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  markdowner:
    path: ../markdowner  # or publish to pub.dev
```

## Usage

```dart
import 'package:markdowner/markdowner.dart';

// Simple usage
MarkdownEditor(
  initialMarkdown: '# Hello\n\nSome **bold** text\n',
  onChanged: (markdown) => print(markdown),
  autofocus: true,
)

// With external controller
final controller = MarkdownEditingController(
  text: '# Hello\n',
  theme: MarkdownEditorTheme.dark(),
);

MarkdownEditor(
  controller: controller,
  theme: MarkdownEditorTheme.dark(),
)
```

See [example/editor_demo.dart](example/editor_demo.dart) for a full working example.

## Architecture

```
lib/
├── markdowner.dart                          # Public API exports
└── src/
    ├── core/markdown_nodes.dart             # AST model (sealed classes)
    ├── parsing/
    │   ├── markdown_grammar.dart            # PetitParser grammar definition
    │   └── markdown_parser.dart             # Parser with AST construction
    ├── rendering/markdown_render_engine.dart # TextSpan tree builder
    ├── theme/markdown_editor_theme.dart      # Theme configuration
    ├── editor/markdown_editing_controller.dart # TextEditingController subclass
    ├── utils/
    │   ├── cursor_mapper.dart               # Delimiter range detection
    │   └── undo_redo_manager.dart           # Undo/redo stack
    └── widgets/markdown_editor.dart         # MarkdownEditor widget
```

## Testing

```bash
flutter test                    # Run all tests (225 passing)
flutter analyze                 # Static analysis (zero issues)
flutter test --coverage         # Generate coverage data
```

## License

MIT
