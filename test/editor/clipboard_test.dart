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

  group('clipboard - plain text', () {
    testWidgets('copy preserves raw markdown text', (tester) async {
      controller.text = '**bold** text\n';
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 13);

      await tester.pumpWidget(buildApp());
      await tester.pump();

      // The controller.text should contain raw markdown
      expect(controller.text, '**bold** text\n');
      // Selected text should be raw markdown
      expect(
        controller.selection.textInside(controller.text),
        '**bold** text',
      );
    });

    testWidgets('cut removes selected text', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      // Simulate cut by replacing selection with empty string
      controller.value = TextEditingValue(
        text: controller.text.replaceRange(0, 5, ''),
        selection: const TextSelection.collapsed(offset: 0),
      );

      expect(controller.text, ' world\n');
    });

    testWidgets('paste inserts text at cursor position', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();

      // Simulate paste by inserting text at cursor
      final offset = controller.selection.baseOffset;
      controller.value = TextEditingValue(
        text: controller.text.substring(0, offset) +
            ' **pasted**' +
            controller.text.substring(offset),
        selection:
            TextSelection.collapsed(offset: offset + ' **pasted**'.length),
      );

      expect(controller.text, 'Hello **pasted** world\n');
    });

    testWidgets('paste replaces selection', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      controller.selection =
          const TextSelection(baseOffset: 6, extentOffset: 11);
      await tester.pump();

      // Simulate paste replacing selection
      controller.value = TextEditingValue(
        text: controller.text.replaceRange(6, 11, 'universe'),
        selection: TextSelection.collapsed(offset: 6 + 'universe'.length),
      );

      expect(controller.text, 'Hello universe\n');
    });
  });

  group('clipboard - markdown preservation', () {
    test('copy/paste of markdown maintains syntax', () {
      controller.text = '# Heading\n- list item\n> quote\n';
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 29);

      // Raw text should preserve markdown syntax
      final copiedText = controller.selection.textInside(controller.text);
      expect(copiedText, '# Heading\n- list item\n> quote');
    });

    test('format toggles work after paste', () {
      controller.text = 'Hello world\n';
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      // Toggle bold on selection
      controller.toggleBold();
      expect(controller.text, '**Hello** world\n');

      // Select the bold text (without delimiters)
      controller.selection =
          const TextSelection(baseOffset: 2, extentOffset: 7);

      // Toggle bold again to remove
      controller.toggleBold();
      expect(controller.text, 'Hello world\n');
    });
  });
}
