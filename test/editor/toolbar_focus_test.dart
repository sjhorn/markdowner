import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/widgets/markdown_editor.dart';

void main() {
  late MarkdownEditingController controller;
  late GlobalKey<MarkdownEditorState> editorKey;

  Widget buildApp({FocusNode? focusNode}) {
    return MaterialApp(
      home: Scaffold(
        body: MarkdownEditor(
          key: editorKey,
          controller: controller,
          focusNode: focusNode,
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

  group('requestEditorFocus', () {
    testWidgets('is accessible on MarkdownEditorState', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // Should not throw — method exists and is callable.
      editorKey.currentState!.requestEditorFocus();
      await tester.pumpAndSettle();
    });
  });

  group('focus save/restore', () {
    testWidgets('saves selection when focus is lost', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(buildApp(focusNode: focusNode));
      await tester.pump();

      // Place cursor at offset 5.
      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();

      // Verify the editor has focus.
      expect(focusNode.hasFocus, isTrue);

      // Remove focus (simulates toolbar click stealing focus).
      focusNode.unfocus();
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);

      // Re-request focus — the saved selection should be restored.
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(controller.selection.baseOffset, 5);
      expect(controller.selection.extentOffset, 5);
    });

    testWidgets('restores range selection after focus round-trip',
        (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(buildApp(focusNode: focusNode));
      await tester.pump();

      // Select "Hello" (0..5).
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      // Focus round-trip.
      focusNode.unfocus();
      await tester.pump();
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, 5);
    });

    testWidgets('requestEditorFocus triggers focus restoration cycle',
        (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(buildApp(focusNode: focusNode));
      await tester.pump();

      // Place cursor at offset 3.
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();

      // Simulate toolbar stealing focus.
      focusNode.unfocus();
      await tester.pump();

      // Toolbar action would call this after toggling format.
      editorKey.currentState!.requestEditorFocus();
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
      expect(controller.selection.baseOffset, 3);
      expect(controller.selection.extentOffset, 3);
    });
  });

  group('restoration guard', () {
    testWidgets('catches platform select-all after focus restoration',
        (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(buildApp(focusNode: focusNode));
      await tester.pump();

      // Place cursor at offset 5.
      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();

      // Focus round-trip.
      focusNode.unfocus();
      await tester.pump();
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Simulate a platform select-all (selection = 0..text.length, text unchanged).
      controller.value = TextEditingValue(
        text: controller.text,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        ),
      );
      await tester.pump();

      // Guard should have caught it and restored offset 5.
      expect(controller.selection.baseOffset, 5);
      expect(controller.selection.extentOffset, 5);
    });

    testWidgets('guard is one-shot — normal edits after restoration pass through',
        (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(buildApp(focusNode: focusNode));
      await tester.pump();

      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();

      // Focus round-trip.
      focusNode.unfocus();
      await tester.pump();
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // First change after restoration: simulate platform select-all.
      controller.value = TextEditingValue(
        text: controller.text,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        ),
      );
      await tester.pump();
      // Guard fires and restores.
      expect(controller.selection.baseOffset, 5);

      // Second change: a real edit. Should NOT be intercepted.
      controller.value = const TextEditingValue(
        text: 'Hello world!\n',
        selection: TextSelection.collapsed(offset: 12),
      );
      await tester.pump();

      expect(controller.text, 'Hello world!\n');
      expect(controller.selection.baseOffset, 12);
    });
  });

  group('performToolbarAction', () {
    testWidgets('restores selection before running action', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(buildApp(focusNode: focusNode));
      await tester.pump();

      // Select "Hello" (0..5).
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      // Simulate toolbar stealing focus.
      focusNode.unfocus();
      await tester.pump();

      // performToolbarAction should restore selection then toggle bold.
      editorKey.currentState!
          .performToolbarAction((s) => s.toggleBold());
      await tester.pumpAndSettle();

      // Bold markers should wrap "Hello", not be appended elsewhere.
      expect(controller.text, '**Hello** world\n');
      // Selection should cover the wrapped text, not the old position.
      expect(controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 7));
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('works with collapsed cursor for toggle', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(buildApp(focusNode: focusNode));
      await tester.pump();

      // Cursor at offset 5 (between "Hello" and " world").
      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();

      // Simulate toolbar stealing focus.
      focusNode.unfocus();
      await tester.pump();

      // toggleBold with collapsed cursor inserts markers at cursor.
      editorKey.currentState!
          .performToolbarAction((s) => s.toggleBold());
      await tester.pumpAndSettle();

      // Markers should be at offset 5, not elsewhere.
      expect(controller.text, 'Hello**** world\n');
      // Cursor should be between the ** pairs (offset 7), not at the old position.
      expect(controller.selection, const TextSelection.collapsed(offset: 7));
    });
  });
}
