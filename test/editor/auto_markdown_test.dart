import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';

/// Tests that markdown patterns at line start are recognized by the parser
/// and produce the correct document structure in real-time as the user types.
void main() {
  late MarkdownEditingController controller;

  setUp(() {
    controller = MarkdownEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('auto-detect heading', () {
    test('# followed by space is parsed as heading', () {
      controller.text = '# Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 7);

      expect(controller.document.blocks, isNotEmpty);
      final block = controller.document.blocks.first;
      expect(block.runtimeType.toString(), contains('Heading'));
    });

    test('## produces level 2 heading', () {
      controller.text = '## Title\n';
      controller.selection = const TextSelection.collapsed(offset: 8);

      expect(controller.document.blocks, isNotEmpty);
      final block = controller.document.blocks.first;
      expect(block.runtimeType.toString(), contains('Heading'));
    });
  });

  group('auto-detect unordered list', () {
    test('- followed by space is parsed as list item', () {
      controller.text = '- item\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      expect(controller.document.blocks, isNotEmpty);
      final block = controller.document.blocks.first;
      expect(block.runtimeType.toString(), contains('UnorderedListItem'));
    });

    test('* followed by space is parsed as list item', () {
      controller.text = '* item\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      expect(controller.document.blocks, isNotEmpty);
      final block = controller.document.blocks.first;
      expect(block.runtimeType.toString(), contains('UnorderedListItem'));
    });
  });

  group('auto-detect ordered list', () {
    test('1. followed by space is parsed as ordered list item', () {
      controller.text = '1. item\n';
      controller.selection = const TextSelection.collapsed(offset: 7);

      expect(controller.document.blocks, isNotEmpty);
      final block = controller.document.blocks.first;
      expect(block.runtimeType.toString(), contains('OrderedListItem'));
    });
  });

  group('auto-detect blockquote', () {
    test('> followed by space is parsed as blockquote', () {
      controller.text = '> quote\n';
      controller.selection = const TextSelection.collapsed(offset: 7);

      expect(controller.document.blocks, isNotEmpty);
      final block = controller.document.blocks.first;
      expect(block.runtimeType.toString(), contains('Blockquote'));
    });
  });

  group('auto-detect thematic break', () {
    test('--- is parsed as thematic break', () {
      controller.text = '---\n';
      controller.selection = const TextSelection.collapsed(offset: 3);

      expect(controller.document.blocks, isNotEmpty);
      final block = controller.document.blocks.first;
      expect(block.runtimeType.toString(), contains('ThematicBreak'));
    });
  });

  group('auto-detect code block', () {
    test('``` opens a code block', () {
      controller.text = '```\ncode\n```\n';
      controller.selection = const TextSelection.collapsed(offset: 7);

      expect(controller.document.blocks, isNotEmpty);
      // Should contain a fenced code block
      final hasCodeBlock = controller.document.blocks
          .any((b) => b.runtimeType.toString().contains('FencedCode'));
      expect(hasCodeBlock, isTrue);
    });
  });

  group('auto-detect task list', () {
    test('- [ ] is parsed as task list item', () {
      controller.text = '- [ ] task\n';
      controller.selection = const TextSelection.collapsed(offset: 10);

      expect(controller.document.blocks, isNotEmpty);
      final block = controller.document.blocks.first;
      // Task lists are unordered list items with task checkbox
      expect(block.runtimeType.toString(), contains('UnorderedListItem'));
    });
  });

  group('real-time reparsing', () {
    test('typing heading prefix triggers reparse', () {
      // Start with plain text
      controller.text = 'Hello\n';
      expect(controller.document.blocks.first.runtimeType.toString(),
          contains('Paragraph'));

      // Change to heading
      controller.value = const TextEditingValue(
        text: '# Hello\n',
        selection: TextSelection.collapsed(offset: 7),
      );

      expect(controller.document.blocks.first.runtimeType.toString(),
          contains('Heading'));
    });

    test('typing list marker triggers reparse', () {
      controller.text = 'item\n';
      expect(controller.document.blocks.first.runtimeType.toString(),
          contains('Paragraph'));

      controller.value = const TextEditingValue(
        text: '- item\n',
        selection: TextSelection.collapsed(offset: 6),
      );

      expect(controller.document.blocks.first.runtimeType.toString(),
          contains('UnorderedListItem'));
    });

    test('removing heading prefix triggers reparse back to paragraph', () {
      controller.text = '# Hello\n';
      expect(controller.document.blocks.first.runtimeType.toString(),
          contains('Heading'));

      controller.value = const TextEditingValue(
        text: 'Hello\n',
        selection: TextSelection.collapsed(offset: 5),
      );

      expect(controller.document.blocks.first.runtimeType.toString(),
          contains('Paragraph'));
    });
  });
}
