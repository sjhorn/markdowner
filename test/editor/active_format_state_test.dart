import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/toolbar/markdown_toolbar.dart';

void main() {
  late MarkdownEditingController controller;

  setUp(() {
    controller = MarkdownEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('activeBlockType', () {
    test('returns paragraph for plain text', () {
      controller.text = 'Hello world\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      expect(controller.activeBlockType, BlockType.paragraph);
    });

    test('returns heading for ATX heading', () {
      controller.text = '# Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 4);

      expect(controller.activeBlockType, BlockType.heading);
    });

    test('returns heading for setext heading', () {
      controller.text = 'Hello\n===\n';
      controller.selection = const TextSelection.collapsed(offset: 3);

      expect(controller.activeBlockType, BlockType.heading);
    });

    test('returns unorderedList for unordered list item', () {
      controller.text = '- item one\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      expect(controller.activeBlockType, BlockType.unorderedList);
    });

    test('returns orderedList for ordered list item', () {
      controller.text = '1. item one\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      expect(controller.activeBlockType, BlockType.orderedList);
    });

    test('returns blockquote for blockquote', () {
      controller.text = '> quoted text\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      expect(controller.activeBlockType, BlockType.blockquote);
    });

    test('returns codeBlock for fenced code block', () {
      controller.text = '```\ncode here\n```\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      expect(controller.activeBlockType, BlockType.codeBlock);
    });

    test('returns thematicBreak for ---', () {
      controller.text = '---\n';
      controller.selection = const TextSelection.collapsed(offset: 1);

      expect(controller.activeBlockType, BlockType.thematicBreak);
    });

    test('returns blank for blank line', () {
      controller.text = 'Hello\n\nWorld\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      expect(controller.activeBlockType, BlockType.blank);
    });

    test('returns table for table block', () {
      controller.text = '| A | B |\n| - | - |\n| 1 | 2 |\n';
      controller.selection = const TextSelection.collapsed(offset: 3);

      expect(controller.activeBlockType, BlockType.table);
    });

    test('returns paragraph when cursor is at invalid position', () {
      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);

      expect(controller.activeBlockType, BlockType.paragraph);
    });
  });

  group('activeHeadingLevel', () {
    test('returns 0 for non-heading block', () {
      controller.text = 'Hello world\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      expect(controller.activeHeadingLevel, 0);
    });

    test('returns 1 for H1', () {
      controller.text = '# Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 4);

      expect(controller.activeHeadingLevel, 1);
    });

    test('returns 3 for H3', () {
      controller.text = '### Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      expect(controller.activeHeadingLevel, 3);
    });

    test('returns 6 for H6', () {
      controller.text = '###### Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 8);

      expect(controller.activeHeadingLevel, 6);
    });

    test('returns correct level for setext heading', () {
      controller.text = 'Hello\n===\n';
      controller.selection = const TextSelection.collapsed(offset: 3);

      expect(controller.activeHeadingLevel, 1);
    });

    test('returns level 2 for setext heading with ---', () {
      controller.text = 'Hello\n---\n';
      // Note: `---` after text on previous line could be setext heading OR thematic break.
      // Depending on parser behavior. If this fails, we adjust expectations.
      controller.selection = const TextSelection.collapsed(offset: 3);

      // Setext headings with --- are level 2
      expect(controller.activeHeadingLevel, 2);
    });
  });

  group('activeInlineFormats', () {
    test('returns empty set for plain text', () {
      controller.text = 'Hello world\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      expect(controller.activeInlineFormats, isEmpty);
    });

    test('returns bold when cursor is inside bold text', () {
      controller.text = 'say **Hello** world\n';
      controller.selection = const TextSelection.collapsed(offset: 7);

      expect(
        controller.activeInlineFormats,
        contains(InlineFormatType.bold),
      );
    });

    test('does not return bold when cursor is outside bold text', () {
      controller.text = 'say **Hello** world\n';
      controller.selection = const TextSelection.collapsed(offset: 2);

      expect(
        controller.activeInlineFormats,
        isNot(contains(InlineFormatType.bold)),
      );
    });

    test('returns italic when cursor is inside italic text', () {
      controller.text = 'say *Hello* world\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      expect(
        controller.activeInlineFormats,
        contains(InlineFormatType.italic),
      );
    });

    test('returns inlineCode when cursor is inside inline code', () {
      controller.text = 'say `code` world\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      expect(
        controller.activeInlineFormats,
        contains(InlineFormatType.inlineCode),
      );
    });

    test('returns strikethrough when cursor is inside strikethrough', () {
      controller.text = 'say ~~deleted~~ world\n';
      controller.selection = const TextSelection.collapsed(offset: 7);

      expect(
        controller.activeInlineFormats,
        contains(InlineFormatType.strikethrough),
      );
    });

    test('returns link when cursor is inside link text', () {
      controller.text = 'see [Flutter](https://flutter.dev) here\n';
      controller.selection = const TextSelection.collapsed(offset: 7);

      expect(
        controller.activeInlineFormats,
        contains(InlineFormatType.link),
      );
    });

    test('returns multiple formats for nested bold+italic', () {
      controller.text = 'say ***bold italic*** world\n';
      controller.selection = const TextSelection.collapsed(offset: 8);

      // BoldItalicInline maps to both bold and italic
      final formats = controller.activeInlineFormats;
      expect(formats, contains(InlineFormatType.bold));
      expect(formats, contains(InlineFormatType.italic));
    });

    test('returns bold for heading content with bold', () {
      controller.text = '# Say **Hello**\n';
      controller.selection = const TextSelection.collapsed(offset: 9);

      expect(
        controller.activeInlineFormats,
        contains(InlineFormatType.bold),
      );
    });

    test('returns empty set for cursor at end of text', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      expect(controller.activeInlineFormats, isEmpty);
    });

    test('returns empty set in code block', () {
      controller.text = '```\n**not bold**\n```\n';
      controller.selection = const TextSelection.collapsed(offset: 8);

      // Code blocks don't have inline children
      expect(controller.activeInlineFormats, isEmpty);
    });

    test('detects highlight at cursor', () {
      controller.text = '==highlighted==\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      expect(
        controller.activeInlineFormats,
        contains(InlineFormatType.highlight),
      );
    });

    test('detects subscript at cursor', () {
      controller.text = '~sub~\n';
      controller.selection = const TextSelection.collapsed(offset: 2);

      expect(
        controller.activeInlineFormats,
        contains(InlineFormatType.subscript),
      );
    });

    test('detects superscript at cursor', () {
      controller.text = '^sup^\n';
      controller.selection = const TextSelection.collapsed(offset: 2);

      expect(
        controller.activeInlineFormats,
        contains(InlineFormatType.superscript),
      );
    });
  });
}
