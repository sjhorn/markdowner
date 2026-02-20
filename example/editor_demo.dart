import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/theme/markdown_editor_theme.dart';
import 'package:markdowner/src/toolbar/markdown_toolbar.dart';
import 'package:markdowner/src/widgets/markdown_editor.dart';

void main() {
  runApp(const EditorDemoApp());
}

enum _EditorThemeMode { light, dark, highContrast }

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
  var _themeMode = _EditorThemeMode.light;
  var _readOnly = false;

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

### Math

Inline math: \$E=mc^2\$ and \$x^2+y^2\$.

\$\$
f(x) = \\int_{-\\infty}^{\\infty} e^{-x^2} dx
\$\$

### Footnotes

This has a footnote[^1] and another[^2].

[^1]: First footnote definition
[^2]: Second footnote definition

### Emoji

Some emoji shortcodes: :smile: :heart: :fire: :rocket: :thumbsup:

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

That was a thematic break above.

[TOC]

Happy editing!
''';

  MarkdownEditorTheme _themeForMode(_EditorThemeMode mode) {
    switch (mode) {
      case _EditorThemeMode.light:
        return MarkdownEditorTheme.light();
      case _EditorThemeMode.dark:
        return MarkdownEditorTheme.dark();
      case _EditorThemeMode.highContrast:
        return MarkdownEditorTheme.highContrast();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = MarkdownEditingController(
      text: _sampleMarkdown,
      theme: _themeForMode(_themeMode),
    );
  }

  void _switchTheme(_EditorThemeMode mode) {
    if (mode == _themeMode) return;
    final text = _controller.text;
    final selection = _controller.selection;
    _controller.dispose();
    _controller = MarkdownEditingController(
      text: text,
      theme: _themeForMode(mode),
    );
    // Restore selection after the new controller is attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.selection = TextSelection.collapsed(
        offset: selection.baseOffset.clamp(0, _controller.text.length),
      );
    });
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showHtmlExport() {
    final html = _controller.toHtml();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HTML Export'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SelectableText(
            html,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: html));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('HTML copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeForMode(_themeMode);

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
          // Theme switcher
          PopupMenuButton<_EditorThemeMode>(
            icon: const Icon(Icons.palette),
            tooltip: 'Switch theme',
            onSelected: _switchTheme,
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: _EditorThemeMode.light,
                checked: _themeMode == _EditorThemeMode.light,
                child: const Text('Light'),
              ),
              CheckedPopupMenuItem(
                value: _EditorThemeMode.dark,
                checked: _themeMode == _EditorThemeMode.dark,
                child: const Text('Dark'),
              ),
              CheckedPopupMenuItem(
                value: _EditorThemeMode.highContrast,
                checked: _themeMode == _EditorThemeMode.highContrast,
                child: const Text('High Contrast'),
              ),
            ],
          ),
          // Read-only toggle
          IconButton(
            icon: Icon(_readOnly ? Icons.edit_off : Icons.edit),
            tooltip: _readOnly ? 'Enable editing' : 'Read-only mode',
            onPressed: () => setState(() => _readOnly = !_readOnly),
          ),
          // Find button
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find (Cmd+F)',
            onPressed: () => _editorKey.currentState?.showFindBar(),
          ),
          // HTML export
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Export HTML',
            onPressed: _showHtmlExport,
          ),
          // Push past the debug ribbon.
          Container(width: 40),
        ],
      ),
      body: Column(
        children: [
          // Toolbar — hidden in read-only mode
          if (!_readOnly)
            Material(
              elevation: 1,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: MarkdownToolbar(
                  controller: _controller,
                  editorKey: _editorKey,
                ),
              ),
            ),
          // Editor
          Expanded(
            child: MarkdownEditor(
              key: _editorKey,
              controller: _controller,
              readOnly: _readOnly,
              theme: theme,
              autofocus: true,
              padding: const EdgeInsets.all(24),
              onImageInsert: (event) async {
                if (!mounted) return null;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Image insert requested (source: ${event.source.name})'),
                  ),
                );
                return 'https://via.placeholder.com/300';
              },
            ),
          ),
          // Status bar
          _StatusBar(controller: _controller),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final MarkdownEditingController controller;

  const _StatusBar({required this.controller});

  String _formatReadingTime(Duration d) {
    if (d.inSeconds < 60) return '< 1 min';
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final stats = controller.stats;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${stats.wordCount} words',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              _divider(context),
              Text(
                '${stats.characterCount} chars',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              _divider(context),
              Text(
                '${stats.lineCount} lines',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              _divider(context),
              Text(
                _formatReadingTime(stats.readingTime),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _divider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '|',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).dividerColor),
      ),
    );
  }
}
