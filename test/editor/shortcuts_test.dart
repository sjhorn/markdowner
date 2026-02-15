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
}
