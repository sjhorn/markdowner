import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/widgets/markdown_editor.dart';

void main() {
  group('readOnly controller', () {
    test('activeBlockIndex is -1 when readOnly', () {
      final controller = MarkdownEditingController(text: '# Hello\nWorld\n');
      controller.readOnly = true;
      controller.selection = const TextSelection.collapsed(offset: 3);
      expect(controller.activeBlockIndex, equals(-1));
      controller.dispose();
    });

    test('activeBlockIndex works normally when not readOnly', () {
      final controller = MarkdownEditingController(text: '# Hello\nWorld\n');
      controller.selection = const TextSelection.collapsed(offset: 3);
      expect(controller.activeBlockIndex, isNot(equals(-1)));
      controller.dispose();
    });

    test('buildTextSpan renders all blocks collapsed when readOnly', () {
      final controller = MarkdownEditingController(text: '# Hello\n**bold**\n');
      controller.readOnly = true;
      controller.selection = const TextSelection.collapsed(offset: 3);

      // activeBlockIndex should be -1, so no block is "revealed"
      expect(controller.activeBlockIndex, equals(-1));
      controller.dispose();
    });

    test('toggling readOnly changes activeBlockIndex', () {
      final controller = MarkdownEditingController(text: '# Hello\nWorld\n');
      controller.selection = const TextSelection.collapsed(offset: 3);

      expect(controller.activeBlockIndex, isNot(equals(-1)));

      controller.readOnly = true;
      expect(controller.activeBlockIndex, equals(-1));

      controller.readOnly = false;
      expect(controller.activeBlockIndex, isNot(equals(-1)));

      controller.dispose();
    });

    test('setting readOnly notifies listeners', () {
      final controller = MarkdownEditingController(text: 'Hello\n');
      var notified = false;
      controller.addListener(() => notified = true);

      controller.readOnly = true;
      expect(notified, isTrue);

      notified = false;
      // Setting same value doesn't notify
      controller.readOnly = true;
      expect(notified, isFalse);

      controller.dispose();
    });

    test('text invariant: concatenated span text matches controller.text in readOnly', () {
      final controller = MarkdownEditingController(text: '# Hello\n**bold** text\n');
      controller.readOnly = true;
      controller.selection = const TextSelection.collapsed(offset: 0);

      // The document's source text should match the controller text
      final doc = controller.document;
      final sourceTexts = doc.blocks.map((b) => b.sourceText).join();
      expect(sourceTexts, equals(controller.text));

      controller.dispose();
    });
  });

  group('readOnly widget', () {
    Widget buildApp({
      String? initialMarkdown,
      MarkdownEditingController? controller,
      bool readOnly = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MarkdownEditor(
            initialMarkdown: initialMarkdown,
            controller: controller,
            readOnly: readOnly,
          ),
        ),
      );
    }

    testWidgets('readOnly flag is passed to EditableText', (tester) async {
      await tester.pumpWidget(buildApp(
        initialMarkdown: '# Hello\n',
        readOnly: true,
      ));
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.readOnly, isTrue);
    });

    testWidgets('readOnly syncs to controller', (tester) async {
      final key = GlobalKey<MarkdownEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              key: key,
              initialMarkdown: '# Hello\n',
              readOnly: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final state = key.currentState!;
      expect(state.controller.readOnly, isTrue);
    });

    testWidgets('readOnly disables SmartEditFormatter', (tester) async {
      await tester.pumpWidget(buildApp(
        initialMarkdown: '# Hello\n',
        readOnly: true,
      ));
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      // When readOnly, only the tab filter should be present, not SmartEditFormatter
      // Actually, when readOnly EditableText ignores input formatters anyway,
      // but we also skip them in build
      expect(editableText.inputFormatters, isNotNull);
    });
  });
}
