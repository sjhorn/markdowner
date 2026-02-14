import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/theme/markdown_editor_theme.dart';
import 'package:markdowner/src/widgets/markdown_editor.dart';

void main() {
  Widget buildApp({
    String? initialMarkdown,
    MarkdownEditingController? controller,
    ValueChanged<String>? onChanged,
    MarkdownEditorTheme? theme,
    bool readOnly = false,
    bool autofocus = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MarkdownEditor(
          initialMarkdown: initialMarkdown,
          controller: controller,
          onChanged: onChanged,
          theme: theme,
          readOnly: readOnly,
          autofocus: autofocus,
        ),
      ),
    );
  }

  group('MarkdownEditor', () {
    testWidgets('renders with initial markdown', (tester) async {
      await tester.pumpWidget(buildApp(initialMarkdown: '# Hello\n'));
      await tester.pump();

      // The EditableText should contain the text
      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.controller.text, equals('# Hello\n'));
    });

    testWidgets('renders with empty initial text', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.controller.text, equals(''));
    });

    testWidgets('uses external controller when provided', (tester) async {
      final controller = MarkdownEditingController(text: '**bold**\n');

      await tester.pumpWidget(buildApp(controller: controller));
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.controller, same(controller));

      controller.dispose();
    });

    testWidgets('applies theme colors', (tester) async {
      final theme = MarkdownEditorTheme.dark();

      await tester.pumpWidget(buildApp(
        initialMarkdown: 'Hello\n',
        theme: theme,
      ));
      await tester.pump();

      // Verify background color on the Container
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.color;
      expect(decoration, equals(theme.backgroundColor));
    });

    testWidgets('calls onChanged when text changes', (tester) async {
      String? changedText;
      await tester.pumpWidget(buildApp(
        initialMarkdown: '',
        onChanged: (text) => changedText = text,
        autofocus: true,
      ));
      await tester.pump();

      // Type some text
      await tester.enterText(find.byType(EditableText), 'Hello');
      await tester.pump();

      expect(changedText, equals('Hello'));
    });

    testWidgets('respects readOnly flag', (tester) async {
      await tester.pumpWidget(buildApp(
        initialMarkdown: 'Read only\n',
        readOnly: true,
      ));
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.readOnly, isTrue);
    });

    testWidgets('disposes owned controller and focus node', (tester) async {
      await tester.pumpWidget(buildApp(initialMarkdown: 'Hello\n'));
      await tester.pump();

      // Remove the widget tree — should not throw
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });

    testWidgets('does not dispose external controller', (tester) async {
      final controller = MarkdownEditingController(text: 'Hello\n');

      await tester.pumpWidget(buildApp(controller: controller));
      await tester.pump();

      // Remove the widget tree
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      // External controller should still be usable
      expect(controller.text, equals('Hello\n'));
      controller.dispose();
    });
  });

  group('MarkdownEditorState', () {
    testWidgets('exposes controller via state', (tester) async {
      final key = GlobalKey<MarkdownEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              key: key,
              initialMarkdown: '# Test\n',
            ),
          ),
        ),
      );
      await tester.pump();

      final state = key.currentState!;
      expect(state.controller.text, equals('# Test\n'));
    });

    testWidgets('exposes undoRedoManager via state', (tester) async {
      final key = GlobalKey<MarkdownEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              key: key,
              initialMarkdown: 'Hello\n',
            ),
          ),
        ),
      );
      await tester.pump();

      final state = key.currentState!;
      expect(state.undoRedoManager, isNotNull);
      expect(state.undoRedoManager.canUndo, isFalse);
    });
  });
}
