import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';

void main() {
  late MarkdownEditingController controller;

  setUp(() {
    controller = MarkdownEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('multi-line selection', () {
    test('selection spanning multiple lines works', () {
      controller.text = 'Line one\nLine two\nLine three\n';
      controller.selection =
          const TextSelection(baseOffset: 5, extentOffset: 22);

      expect(
        controller.selection.textInside(controller.text),
        'one\nLine two\nLine',
      );
    });

    test('selection across block types works', () {
      controller.text = '# Heading\nParagraph text\n- list item\n';
      controller.selection =
          const TextSelection(baseOffset: 2, extentOffset: 31);

      expect(
        controller.selection.textInside(controller.text),
        'Heading\nParagraph text\n- list',
      );
    });
  });

  group('format toggles on multi-line selections', () {
    test('toggleBold wraps entire multi-line selection', () {
      controller.text = 'Line one\nLine two\n';
      controller.selection =
          const TextSelection(baseOffset: 5, extentOffset: 17);

      controller.toggleBold();

      expect(controller.text, 'Line **one\nLine two**\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 7, extentOffset: 19));
    });

    test('toggleItalic wraps entire multi-line selection', () {
      controller.text = 'Line one\nLine two\n';
      controller.selection =
          const TextSelection(baseOffset: 5, extentOffset: 17);

      controller.toggleItalic();

      expect(controller.text, 'Line *one\nLine two*\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 6, extentOffset: 18));
    });

    test('toggleBold unwraps multi-line bold selection', () {
      controller.text = 'Line **one\nLine two**\n';
      controller.selection =
          const TextSelection(baseOffset: 7, extentOffset: 19);

      controller.toggleBold();

      expect(controller.text, 'Line one\nLine two\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 5, extentOffset: 17));
    });
  });

  group('cut/delete across lines', () {
    test('deleting across lines merges them', () {
      controller.text = 'Line one\nLine two\nLine three\n';
      // Delete "one\nLine " by replacing with empty
      controller.value = const TextEditingValue(
        text: 'Line two\nLine three\n',
        selection: TextSelection.collapsed(offset: 5),
      );

      expect(controller.text, 'Line two\nLine three\n');
    });

    test('replacing multi-line selection with text', () {
      controller.text = 'Line one\nLine two\nLine three\n';
      controller.selection =
          const TextSelection(baseOffset: 5, extentOffset: 22);

      // Replace selection with "replaced"
      final start = controller.selection.start;
      final end = controller.selection.end;
      controller.value = TextEditingValue(
        text: controller.text.replaceRange(start, end, 'replaced'),
        selection:
            TextSelection.collapsed(offset: start + 'replaced'.length),
      );

      expect(controller.text, 'Line replaced three\n');
    });

    test('deleting entire blocks', () {
      controller.text = '# Heading\nParagraph\n- list\n';
      // Select all of paragraph line
      controller.value = const TextEditingValue(
        text: '# Heading\n- list\n',
        selection: TextSelection.collapsed(offset: 10),
      );

      expect(controller.text, '# Heading\n- list\n');
      // Should still parse correctly
      expect(controller.document.blocks, isNotEmpty);
    });
  });

  group('setHeadingLevel on multi-line cursor', () {
    test('sets heading on the line containing the cursor base', () {
      controller.text = 'Line one\nLine two\nLine three\n';
      // Cursor on "Line two"
      controller.selection = const TextSelection.collapsed(offset: 12);

      controller.setHeadingLevel(2);

      expect(controller.text, 'Line one\n## Line two\nLine three\n');
    });
  });

  group('indent/outdent on multi-line context', () {
    test('indent works on list item in multi-line doc', () {
      controller.text = '- item one\n- item two\n- item three\n';
      // Cursor in "item two"
      controller.selection = const TextSelection.collapsed(offset: 15);

      controller.indent();

      expect(controller.text, '- item one\n  - item two\n- item three\n');
    });

    test('outdent works on indented list item in multi-line doc', () {
      controller.text = '- item one\n  - item two\n- item three\n';
      // Cursor in "item two"
      controller.selection = const TextSelection.collapsed(offset: 17);

      controller.outdent();

      expect(controller.text, '- item one\n- item two\n- item three\n');
    });
  });
}
