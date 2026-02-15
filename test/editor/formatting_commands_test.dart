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

  group('toggleBold', () {
    test('wraps selected text with **', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      controller.toggleBold();

      expect(controller.text, '**Hello**\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 7));
    });

    test('unwraps already bold text', () {
      controller.text = '**Hello**\n';
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 7);

      controller.toggleBold();

      expect(controller.text, 'Hello\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5));
    });

    test('inserts empty bold markers at collapsed cursor', () {
      controller.text = 'Hello\n';
      controller.selection =
          const TextSelection.collapsed(offset: 5);

      controller.toggleBold();

      expect(controller.text, 'Hello****\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 7));
    });

    test('works mid-line', () {
      controller.text = 'say Hello world\n';
      controller.selection = const TextSelection(baseOffset: 4, extentOffset: 9);

      controller.toggleBold();

      expect(controller.text, 'say **Hello** world\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 6, extentOffset: 11));
    });
  });

  group('toggleItalic', () {
    test('wraps selected text with *', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      controller.toggleItalic();

      expect(controller.text, '*Hello*\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 1, extentOffset: 6));
    });

    test('unwraps already italic text', () {
      controller.text = '*Hello*\n';
      controller.selection = const TextSelection(baseOffset: 1, extentOffset: 6);

      controller.toggleItalic();

      expect(controller.text, 'Hello\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5));
    });

    test('inserts empty italic markers at collapsed cursor', () {
      controller.text = 'Hello\n';
      controller.selection =
          const TextSelection.collapsed(offset: 5);

      controller.toggleItalic();

      expect(controller.text, 'Hello**\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 6));
    });

    test('works mid-line', () {
      controller.text = 'say Hello world\n';
      controller.selection = const TextSelection(baseOffset: 4, extentOffset: 9);

      controller.toggleItalic();

      expect(controller.text, 'say *Hello* world\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 5, extentOffset: 10));
    });
  });

  group('toggleInlineCode', () {
    test('wraps selected text with backtick', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      controller.toggleInlineCode();

      expect(controller.text, '`Hello`\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 1, extentOffset: 6));
    });

    test('unwraps already code text', () {
      controller.text = '`Hello`\n';
      controller.selection = const TextSelection(baseOffset: 1, extentOffset: 6);

      controller.toggleInlineCode();

      expect(controller.text, 'Hello\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5));
    });

    test('inserts empty code markers at collapsed cursor', () {
      controller.text = 'Hello\n';
      controller.selection =
          const TextSelection.collapsed(offset: 5);

      controller.toggleInlineCode();

      expect(controller.text, 'Hello``\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 6));
    });
  });

  group('toggleStrikethrough', () {
    test('wraps selected text with ~~', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      controller.toggleStrikethrough();

      expect(controller.text, '~~Hello~~\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 7));
    });

    test('unwraps already strikethrough text', () {
      controller.text = '~~Hello~~\n';
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 7);

      controller.toggleStrikethrough();

      expect(controller.text, 'Hello\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5));
    });

    test('inserts empty strikethrough markers at collapsed cursor', () {
      controller.text = 'Hello\n';
      controller.selection =
          const TextSelection.collapsed(offset: 5);

      controller.toggleStrikethrough();

      expect(controller.text, 'Hello~~~~\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 7));
    });
  });

  group('setHeadingLevel', () {
    test('sets heading level 1', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 3);

      controller.setHeadingLevel(1);

      expect(controller.text, '# Hello\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 5));
    });

    test('sets heading level 3', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 3);

      controller.setHeadingLevel(3);

      expect(controller.text, '### Hello\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 7));
    });

    test('replaces existing heading prefix', () {
      controller.text = '# Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 4);

      controller.setHeadingLevel(3);

      expect(controller.text, '### Hello\n');
      // cursor was at offset 4 in "# Hello", that's 2 chars into "Hello"
      // new prefix is "### " (4 chars), cursor should be at 4 + (4-2) = 6
      expect(controller.selection,
          const TextSelection.collapsed(offset: 6));
    });

    test('removes heading prefix with level 0', () {
      controller.text = '## Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      controller.setHeadingLevel(0);

      expect(controller.text, 'Hello\n');
      // cursor was at offset 5 in "## Hello", that's 2 chars into "Hello"
      // prefix removed (3 chars "## "), cursor should be at 5 - 3 = 2
      expect(controller.selection,
          const TextSelection.collapsed(offset: 2));
    });

    test('works on correct line in multi-line text', () {
      controller.text = 'Line one\nLine two\nLine three\n';
      // Cursor on "Line two" (offset 10 = start of "L" in "Line two")
      controller.selection = const TextSelection.collapsed(offset: 10);

      controller.setHeadingLevel(2);

      expect(controller.text, 'Line one\n## Line two\nLine three\n');
      // prefix "## " added (3 chars), cursor was at 10, now at 13
      expect(controller.selection,
          const TextSelection.collapsed(offset: 13));
    });

    test('setting same level removes the heading', () {
      controller.text = '## Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      controller.setHeadingLevel(2);

      expect(controller.text, 'Hello\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 2));
    });
  });
}
