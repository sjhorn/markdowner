import 'package:flutter/material.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/theme/markdown_editor_theme.dart';
import 'package:markdowner/src/widgets/markdown_editor.dart';

void main() {
  runApp(const EditorDemoApp());
}

class EditorDemoApp extends StatelessWidget {
  const EditorDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdowner Editor Demo',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const EditorDemoPage(),
    );
  }
}

class EditorDemoPage extends StatefulWidget {
  const EditorDemoPage({super.key});

  @override
  State<EditorDemoPage> createState() => _EditorDemoPageState();
}

class _EditorDemoPageState extends State<EditorDemoPage> {
  late MarkdownEditingController _controller;
  final _editorKey = GlobalKey<MarkdownEditorState>();

  static const _sampleMarkdown = '''# Welcome to Markdowner

This is a **WYSIWYG markdown editor** built with Flutter.

## Features

Try placing your cursor on different lines:

- When the cursor is **inside** a block, you see the raw *markdown syntax*
- When the cursor **leaves**, syntax collapses and content renders with `rich formatting`
- [x] Phase 1 complete
- [ ] Phase 2 in progress

### Inline Styles

Here is some **bold text** and some *italic text*.

You can also use ***bold italic*** together.

Inline `code` looks like this, and ~~strikethrough~~ like this.

Escaped characters: \\* \\# \\~

### Links and Images

Visit [Flutter](https://flutter.dev "Flutter website") for more info.

Check out <https://dart.dev> too.

Here is an image: ![Dash](https://flutter.dev/dash.png)

### Code Blocks

```dart
void main() {
  print('Hello, Markdowner!');
}
```

### Blockquotes

> This is a blockquote with **bold** text.
> Blockquotes can span multiple lines.

### Ordered Lists

1. First item
2. Second item
3. Third item

***

That was a thematic break above. Happy editing!
''';

  @override
  void initState() {
    super.initState();
    _controller = MarkdownEditingController(
      text: _sampleMarkdown,
      theme: MarkdownEditorTheme.light(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildUndoDropdown() {
    return PopupMenuButton<int>(
      tooltip: 'Undo history',
      offset: const Offset(0, kToolbarHeight),
      onSelected: (index) {
        _editorKey.currentState?.undoSteps(index + 1);
        setState(() {});
      },
      itemBuilder: (context) {
        final names = _editorKey.currentState?.undoNames ?? [];
        if (names.isEmpty) {
          return [
            const PopupMenuItem<int>(
              enabled: false,
              child: Text('No undo history'),
            ),
          ];
        }
        return [
          for (var i = 0; i < names.length; i++)
            PopupMenuItem<int>(
              value: i,
              child: Text(names[i]),
            ),
        ];
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.undo),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildRedoDropdown() {
    return PopupMenuButton<int>(
      tooltip: 'Redo history',
      offset: const Offset(0, kToolbarHeight),
      onSelected: (index) {
        _editorKey.currentState?.redoSteps(index + 1);
        setState(() {});
      },
      itemBuilder: (context) {
        final names = _editorKey.currentState?.redoNames ?? [];
        if (names.isEmpty) {
          return [
            const PopupMenuItem<int>(
              enabled: false,
              child: Text('No redo history'),
            ),
          ];
        }
        return [
          for (var i = 0; i < names.length; i++)
            PopupMenuItem<int>(
              value: i,
              child: Text(names[i]),
            ),
        ];
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.redo),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/markdowner.png', height: 48),
            Container(width: 10),
            const Text('markdowner demo'),
          ],
        ),
        actions: [
          _buildUndoDropdown(),
          _buildRedoDropdown(),
          // Push past the debug ribbon.
          Container(width: 40),
        ],
      ),
      body: MarkdownEditor(
        key: _editorKey,
        controller: _controller,
        autofocus: true,
        padding: const EdgeInsets.all(24),
      ),
    );
  }
}
