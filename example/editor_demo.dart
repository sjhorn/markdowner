import 'package:flutter/material.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/theme/markdown_editor_theme.dart';
import 'package:markdowner/src/toolbar/markdown_toolbar.dart';
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

Try ==highlighted text== for emphasis, H~2~O for subscript, and x^2^ for superscript.

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
          // Push past the debug ribbon.
          Container(width: 40),
        ],
      ),
      body: Column(
        children: [
          Material(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: MarkdownToolbar(
                controller: _controller,
                editorKey: _editorKey,
              ),
            ),
          ),
          Expanded(
            child: MarkdownEditor(
              key: _editorKey,
              controller: _controller,
              autofocus: true,
              padding: const EdgeInsets.all(24),
            ),
          ),
        ],
      ),
    );
  }
}
