import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/toolbar/markdown_toolbar.dart';
import 'package:markdowner/src/widgets/markdown_editor.dart';

void main() {
  group('MarkdownToolbar', () {
    late MarkdownEditingController controller;
    late GlobalKey<MarkdownEditorState> editorKey;

    setUp(() {
      controller = MarkdownEditingController();
      editorKey = GlobalKey<MarkdownEditorState>();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildToolbarApp({
      String? initialText,
      List<MarkdownToolbarItem>? items,
    }) {
      if (initialText != null) {
        controller = MarkdownEditingController(text: initialText);
      }
      return MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MarkdownToolbar(
                controller: controller,
                editorKey: editorKey,
                items: items,
              ),
              Expanded(
                child: MarkdownEditor(
                  key: editorKey,
                  controller: controller,
                  autofocus: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders default toolbar buttons', (tester) async {
      await tester.pumpWidget(buildToolbarApp());
      await tester.pumpAndSettle();

      // Check that key toolbar buttons are present via their tooltips.
      expect(find.byTooltip('Bold'), findsOneWidget);
      expect(find.byTooltip('Italic'), findsOneWidget);
      expect(find.byTooltip('Inline code'), findsOneWidget);
      expect(find.byTooltip('Strikethrough'), findsOneWidget);
      expect(find.byTooltip('Heading level'), findsOneWidget);
      expect(find.byTooltip('Insert link'), findsOneWidget);
      expect(find.byTooltip('Toggle code block'), findsOneWidget);
      expect(find.byTooltip('Indent'), findsOneWidget);
      expect(find.byTooltip('Outdent'), findsOneWidget);
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(find.byTooltip('Redo'), findsOneWidget);
    });

    testWidgets('renders only specified items', (tester) async {
      await tester.pumpWidget(buildToolbarApp(
        items: [MarkdownToolbarItem.bold, MarkdownToolbarItem.italic],
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Bold'), findsOneWidget);
      expect(find.byTooltip('Italic'), findsOneWidget);
      expect(find.byTooltip('Inline code'), findsNothing);
      expect(find.byTooltip('Undo'), findsNothing);
    });

    testWidgets('bold button triggers toggleBold on editor', (tester) async {
      await tester.pumpWidget(buildToolbarApp(
        initialText: 'Hello\n',
      ));
      await tester.pumpAndSettle();

      // Place cursor with a selection in the editor.
      final state = editorKey.currentState!;
      state.controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      // Tap the bold button.
      await tester.tap(find.byTooltip('Bold'));
      await tester.pumpAndSettle();

      expect(controller.text, '**Hello**\n');
    });

    testWidgets('italic button triggers toggleItalic on editor',
        (tester) async {
      await tester.pumpWidget(buildToolbarApp(
        initialText: 'Hello\n',
      ));
      await tester.pumpAndSettle();

      final state = editorKey.currentState!;
      state.controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      await tester.tap(find.byTooltip('Italic'));
      await tester.pumpAndSettle();

      expect(controller.text, '*Hello*\n');
    });

    testWidgets('inline code button triggers toggleInlineCode', (tester) async {
      await tester.pumpWidget(buildToolbarApp(
        initialText: 'Hello\n',
      ));
      await tester.pumpAndSettle();

      final state = editorKey.currentState!;
      state.controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      await tester.tap(find.byTooltip('Inline code'));
      await tester.pumpAndSettle();

      expect(controller.text, '`Hello`\n');
    });

    testWidgets('strikethrough button triggers toggleStrikethrough',
        (tester) async {
      await tester.pumpWidget(buildToolbarApp(
        initialText: 'Hello\n',
      ));
      await tester.pumpAndSettle();

      final state = editorKey.currentState!;
      state.controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      await tester.tap(find.byTooltip('Strikethrough'));
      await tester.pumpAndSettle();

      expect(controller.text, '~~Hello~~\n');
    });

    testWidgets('heading dropdown sets heading level', (tester) async {
      await tester.pumpWidget(buildToolbarApp(
        initialText: 'Hello\n',
      ));
      await tester.pumpAndSettle();

      final state = editorKey.currentState!;
      state.controller.selection =
          const TextSelection.collapsed(offset: 3);
      await tester.pump();

      // Tap the heading dropdown.
      await tester.tap(find.byTooltip('Heading level'));
      await tester.pumpAndSettle();

      // Select H2.
      await tester.tap(find.text('H2'));
      await tester.pumpAndSettle();

      expect(controller.text, '## Hello\n');
    });

    testWidgets('toolbar updates when controller changes', (tester) async {
      await tester.pumpWidget(buildToolbarApp(
        initialText: 'say **Hello** world\n',
      ));
      await tester.pumpAndSettle();

      // Initially cursor outside bold — bold button should not be active.
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();

      // Find the bold icon button.
      final boldButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Bold'),
          matching: find.byType(IconButton),
        ),
      );
      expect(boldButton.isSelected, false);

      // Move cursor inside bold text.
      controller.selection = const TextSelection.collapsed(offset: 7);
      await tester.pump();

      final boldButtonAfter = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Bold'),
          matching: find.byType(IconButton),
        ),
      );
      expect(boldButtonAfter.isSelected, true);
    });

    testWidgets('link button triggers insertLink', (tester) async {
      await tester.pumpWidget(buildToolbarApp(
        initialText: 'Hello\n',
      ));
      await tester.pumpAndSettle();

      final state = editorKey.currentState!;
      state.controller.selection =
          const TextSelection.collapsed(offset: 5);
      await tester.pump();

      await tester.tap(find.byTooltip('Insert link'));
      await tester.pumpAndSettle();

      expect(controller.text, 'Hello[](url)\n');
    });

    testWidgets('code block button triggers toggleCodeBlock', (tester) async {
      await tester.pumpWidget(buildToolbarApp(
        initialText: 'some code\n',
      ));
      await tester.pumpAndSettle();

      final state = editorKey.currentState!;
      state.controller.selection =
          const TextSelection.collapsed(offset: 5);
      await tester.pump();

      await tester.tap(find.byTooltip('Toggle code block'));
      await tester.pumpAndSettle();

      expect(controller.text, '```\nsome code\n```\n');
    });

    testWidgets('dividers appear between toolbar groups', (tester) async {
      await tester.pumpWidget(buildToolbarApp());
      await tester.pumpAndSettle();

      // Dividers should exist between the groups.
      expect(find.byType(VerticalDivider), findsWidgets);
    });
  });
}
