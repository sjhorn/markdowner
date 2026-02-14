import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:markdowner/markdowner.dart';

void main() {
  group('MarkdownEditingController', () {
    test('parses initial text into document', () {
      final controller = MarkdownEditingController(text: '# Hello\n');
      expect(controller.document.blocks.length, equals(1));
      expect(controller.document.blocks[0], isA<HeadingBlock>());
      controller.dispose();
    });

    test('empty text produces empty document', () {
      final controller = MarkdownEditingController();
      expect(controller.document.blocks, isEmpty);
      controller.dispose();
    });

    test('reparses when text changes', () {
      final controller = MarkdownEditingController(text: 'Hello\n');
      expect(controller.document.blocks.length, equals(1));
      expect(controller.document.blocks[0], isA<ParagraphBlock>());

      controller.text = '# Heading\n';
      expect(controller.document.blocks.length, equals(1));
      expect(controller.document.blocks[0], isA<HeadingBlock>());
      controller.dispose();
    });

    test('activeBlockIndex returns correct index based on selection', () {
      final controller = MarkdownEditingController(text: '# Heading\nParagraph\n');
      // Cursor at offset 0 (in heading)
      controller.selection = const TextSelection.collapsed(offset: 0);
      expect(controller.activeBlockIndex, equals(0));

      // Cursor at offset 12 (in paragraph)
      controller.selection = const TextSelection.collapsed(offset: 12);
      expect(controller.activeBlockIndex, equals(1));
      controller.dispose();
    });

    test('activeBlockIndex returns -1 with no selection', () {
      final controller = MarkdownEditingController(text: 'Hello\n');
      // Default selection offset is -1
      controller.selection = const TextSelection.collapsed(offset: -1);
      expect(controller.activeBlockIndex, equals(-1));
      controller.dispose();
    });

    test('toMarkdown roundtrips through controller', () {
      const source = '# Title\n\nSome **bold** text\n---\n';
      final controller = MarkdownEditingController(text: source);
      expect(controller.document.toMarkdown(), equals(source));
      controller.dispose();
    });

    test('document getter returns parsed document', () {
      final controller = MarkdownEditingController(
        text: 'Hello **world**\n',
      );
      final doc = controller.document;
      expect(doc.blocks.length, equals(1));
      final block = doc.blocks[0] as ParagraphBlock;
      expect(block.children.length, equals(2));
      expect(block.children[0], isA<PlainTextInline>());
      expect(block.children[1], isA<BoldInline>());
      controller.dispose();
    });

    test('theme getter returns the configured theme', () {
      final theme = MarkdownEditorTheme.dark();
      final controller = MarkdownEditingController(
        text: 'Hello\n',
        theme: theme,
      );
      expect(controller.theme, same(theme));
      controller.dispose();
    });

    test('uses light theme by default', () {
      final controller = MarkdownEditingController(text: 'Hello\n');
      expect(controller.theme.backgroundColor, equals(const Color(0xFFFFFFFF)));
      controller.dispose();
    });
  });

  group('buildTextSpan', () {
    testWidgets('returns empty span for empty text', (tester) async {
      final controller = MarkdownEditingController();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final span = controller.buildTextSpan(
                context: context,
                withComposing: false,
              );
              expect(span.text, equals(''));
              return const SizedBox();
            },
          ),
        ),
      );
      controller.dispose();
    });

    testWidgets('builds span tree for markdown content', (tester) async {
      final controller = MarkdownEditingController(text: '**bold**\n');
      controller.selection = const TextSelection.collapsed(offset: 4);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final span = controller.buildTextSpan(
                context: context,
                withComposing: false,
              );
              // Should have children (block spans)
              expect(span.children, isNotNull);
              expect(span.children, isNotEmpty);
              return const SizedBox();
            },
          ),
        ),
      );
      controller.dispose();
    });

    testWidgets('text invariant: all span text equals controller text',
        (tester) async {
      final controller = MarkdownEditingController(
        text: '# Title\n\nSome **bold** *italic* `code`\n---\n',
      );
      controller.selection = const TextSelection.collapsed(offset: 15);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final span = controller.buildTextSpan(
                context: context,
                withComposing: false,
              );
              final allText = _extractAllText(span);
              expect(allText, equals(controller.text));
              return const SizedBox();
            },
          ),
        ),
      );
      controller.dispose();
    });

    testWidgets('active block gets revealed styling, others get collapsed',
        (tester) async {
      final theme = MarkdownEditorTheme.light();
      final controller = MarkdownEditingController(
        text: '# Heading\nParagraph\n',
        theme: theme,
      );
      // Cursor in paragraph block (offset 12)
      controller.selection = const TextSelection.collapsed(offset: 12);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final span = controller.buildTextSpan(
                context: context,
                withComposing: false,
              );
              // First block (heading) should be collapsed — prefix uses hiddenSyntaxStyle
              final headingBlock = span.children![0] as TextSpan;
              final headingPrefix =
                  headingBlock.children![0] as TextSpan;
              expect(headingPrefix.style, equals(theme.hiddenSyntaxStyle));

              // Second block (paragraph) should be revealed — base style
              final paragraphBlock = span.children![1] as TextSpan;
              final paragraphText =
                  paragraphBlock.children![0] as TextSpan;
              expect(paragraphText.style, equals(theme.baseStyle));

              return const SizedBox();
            },
          ),
        ),
      );
      controller.dispose();
    });
  });
}

String _extractAllText(TextSpan span) {
  final buffer = StringBuffer();
  _collectText(span, buffer);
  return buffer.toString();
}

void _collectText(TextSpan span, StringBuffer buffer) {
  if (span.text != null) {
    buffer.write(span.text);
  }
  if (span.children != null) {
    for (final child in span.children!) {
      _collectText(child as TextSpan, buffer);
    }
  }
}
