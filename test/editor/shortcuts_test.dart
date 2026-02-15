import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/widgets/markdown_editor.dart';

void main() {
  late MarkdownEditingController controller;
  late GlobalKey<MarkdownEditorState> editorKey;

  Widget buildApp() {
    return MaterialApp(
      home: Scaffold(
        body: MarkdownEditor(
          key: editorKey,
          controller: controller,
          autofocus: true,
        ),
      ),
    );
  }

  setUp(() {
    controller = MarkdownEditingController(text: 'Hello world\n');
    editorKey = GlobalKey<MarkdownEditorState>();
  });

  tearDown(() {
    controller.dispose();
  });

  /// Send a key combination using the platform-appropriate modifier.
  Future<void> sendShortcut(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    final useMeta = defaultTargetPlatform == TargetPlatform.macOS;
    await tester.sendKeyDownEvent(
        useMeta ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft);
    if (shift) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    }
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    if (shift) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    }
    await tester.sendKeyUpEvent(
        useMeta ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  group('formatting shortcuts', () {
    testWidgets('Cmd/Ctrl+B toggles bold', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // Select "Hello"
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.keyB);

      expect(controller.text, '**Hello** world\n');
    });

    testWidgets('Cmd/Ctrl+I toggles italic', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.keyI);

      expect(controller.text, '*Hello* world\n');
    });

    testWidgets('Cmd/Ctrl+Shift+K toggles strikethrough', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.keyK, shift: true);

      expect(controller.text, '~~Hello~~ world\n');
    });

    testWidgets('Cmd/Ctrl+` toggles inline code', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.backquote);

      expect(controller.text, '`Hello` world\n');
    });
  });

  group('heading shortcuts', () {
    testWidgets('Cmd/Ctrl+1 sets heading level 1', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.digit1);

      expect(controller.text, '# Hello world\n');
    });

    testWidgets('Cmd/Ctrl+3 sets heading level 3', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.digit3);

      expect(controller.text, '### Hello world\n');
    });

    testWidgets('Cmd/Ctrl+0 clears heading', (tester) async {
      controller.text = '## Hello world\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      await tester.pumpWidget(buildApp());
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.digit0);

      expect(controller.text, 'Hello world\n');
    });
  });

  group('undo/redo shortcuts', () {
    testWidgets('Cmd/Ctrl+Z triggers undo', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // Make a change to create undo history
      controller.text = 'Changed\n';
      controller.selection = const TextSelection.collapsed(offset: 8);
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.keyZ);

      expect(controller.text, 'Hello world\n');
    });

    testWidgets('Cmd/Ctrl+Shift+Z triggers redo', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // Make a change
      controller.text = 'Changed\n';
      controller.selection = const TextSelection.collapsed(offset: 8);
      await tester.pump();

      // Undo
      await sendShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(controller.text, 'Hello world\n');

      // Redo
      await sendShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(controller.text, 'Changed\n');
    });
  });

  group('MarkdownEditorState exposes toggle methods', () {
    testWidgets('toggleBold is accessible via state', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      editorKey.currentState!.toggleBold();

      expect(controller.text, '**Hello** world\n');
    });

    testWidgets('toggleItalic is accessible via state', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      editorKey.currentState!.toggleItalic();

      expect(controller.text, '*Hello* world\n');
    });

    testWidgets('toggleInlineCode is accessible via state', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      editorKey.currentState!.toggleInlineCode();

      expect(controller.text, '`Hello` world\n');
    });

    testWidgets('toggleStrikethrough is accessible via state', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      editorKey.currentState!.toggleStrikethrough();

      expect(controller.text, '~~Hello~~ world\n');
    });

    testWidgets('setHeadingLevel is accessible via state', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection = const TextSelection.collapsed(offset: 3);

      editorKey.currentState!.setHeadingLevel(2);

      expect(controller.text, '## Hello world\n');
    });
  });

  group('indent/outdent shortcuts', () {
    testWidgets('Tab indents list item', (tester) async {
      controller.text = '- item\n';
      controller.selection = const TextSelection.collapsed(offset: 4);

      await tester.pumpWidget(buildApp());
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(controller.text, '  - item\n');
    });

    testWidgets('Shift+Tab outdents list item', (tester) async {
      controller.text = '  - item\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      await tester.pumpWidget(buildApp());
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(controller.text, '- item\n');
    });

    testWidgets('Cmd/Ctrl+Shift+] indents list item', (tester) async {
      controller.text = '- item\n';
      controller.selection = const TextSelection.collapsed(offset: 4);

      await tester.pumpWidget(buildApp());
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.bracketRight, shift: true);

      expect(controller.text, '  - item\n');
    });

    testWidgets('Cmd/Ctrl+Shift+[ outdents list item', (tester) async {
      controller.text = '  - item\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      await tester.pumpWidget(buildApp());
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.bracketLeft, shift: true);

      expect(controller.text, '- item\n');
    });

    testWidgets('Tab inserts 2 spaces in non-list context', (tester) async {
      controller.text = 'Hello world\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      await tester.pumpWidget(buildApp());
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // 2 spaces inserted at offset 5 + original space = 3 spaces
      expect(controller.text, 'Hello   world\n');
    });
  });

  group('insert link shortcut', () {
    testWidgets('Cmd/Ctrl+K inserts link at collapsed cursor', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.keyK);

      expect(controller.text, 'Hello[](url) world\n');
    });

    testWidgets('Cmd/Ctrl+K wraps selection as link', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.keyK);

      expect(controller.text, '[Hello](url) world\n');
    });
  });

  group('toggle code block shortcut', () {
    testWidgets('Cmd/Ctrl+Shift+C wraps line in code fences', (tester) async {
      controller.text = 'some code\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      await tester.pumpWidget(buildApp());
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.keyC, shift: true);

      expect(controller.text, '```\nsome code\n```\n');
    });
  });

  group('save shortcut', () {
    testWidgets('Cmd/Ctrl+S triggers onSaved callback', (tester) async {
      String? savedText;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownEditor(
            key: editorKey,
            controller: controller,
            autofocus: true,
            onSaved: (text) => savedText = text,
          ),
        ),
      ));
      await tester.pump();

      await sendShortcut(tester, LogicalKeyboardKey.keyS);

      expect(savedText, 'Hello world\n');
    });

    testWidgets('Cmd/Ctrl+S no-op when onSaved is null', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // Should not throw.
      await sendShortcut(tester, LogicalKeyboardKey.keyS);

      expect(controller.text, 'Hello world\n');
    });
  });

  group('MarkdownEditorState exposes new methods', () {
    testWidgets('insertLink is accessible via state', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection = const TextSelection.collapsed(offset: 5);

      editorKey.currentState!.insertLink();

      expect(controller.text, 'Hello[](url) world\n');
    });

    testWidgets('toggleCodeBlock is accessible via state', (tester) async {
      controller.text = 'some code\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      await tester.pumpWidget(buildApp());
      await tester.pump();

      editorKey.currentState!.toggleCodeBlock();

      expect(controller.text, '```\nsome code\n```\n');
    });
  });
}
