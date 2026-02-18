import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';

/// Generate a markdown document with approximately [lines] lines.
String _generateMarkdown(int lines) {
  final buffer = StringBuffer();
  var lineCount = 0;

  while (lineCount < lines) {
    if (lineCount % 20 == 0) {
      buffer.write('## Section ${lineCount ~/ 20 + 1}\n\n');
      lineCount += 2;
    }
    buffer.write(
        'This is paragraph $lineCount with **bold** and *italic* text.\n\n');
    lineCount += 2;
    if (lineCount >= lines) break;
    if (lineCount % 10 == 0) {
      buffer.write('- Item one with `code`\n');
      buffer.write('- Item two with [link](http://example.com)\n');
      buffer.write('- Item three\n\n');
      lineCount += 4;
    }
    if (lineCount >= lines) break;
  }

  return buffer.toString();
}

/// Minimal BuildContext stub for testing buildTextSpan outside a widget tree.
class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Count the number of direct children in a TextSpan tree that are plain
/// (have text but no children — indicating an unstyled block).
int _countPlainChildren(TextSpan span) {
  if (span.children == null) return 0;
  var count = 0;
  for (final child in span.children!) {
    if (child is TextSpan && child.text != null && child.children == null) {
      count++;
    }
  }
  return count;
}

/// Count the number of direct children in a TextSpan tree that are styled
/// (have children — indicating a block rendered with per-inline styling).
int _countStyledChildren(TextSpan span) {
  if (span.children == null) return 0;
  var count = 0;
  for (final child in span.children!) {
    if (child is TextSpan && child.children != null) {
      count++;
    }
  }
  return count;
}

void main() {
  group('lazy span building (cursor-proximity)', () {
    test('small doc (<100 blocks) gets all blocks styled', () {
      final text = _generateMarkdown(50);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      expect(controller.document.blocks.length, lessThanOrEqualTo(100));

      controller.selection = const TextSelection.collapsed(offset: 0);

      final span = controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );

      // All blocks should be styled (no plain-text-only shortcuts).
      expect(span.children, isNotNull);
      expect(span.children!.length, equals(controller.document.blocks.length));

      // Every block should have styled treatment (children sub-spans or
      // at minimum be present — no blocks should be skipped).
      final styledCount = _countStyledChildren(span);
      // At least some blocks should have styled children (headings, paragraphs
      // with bold/italic). Plain blocks like blank lines are text-only.
      expect(styledCount, greaterThan(0));
    });

    test('large doc (500+ blocks), cursor at middle: near-cursor styled, far blocks plain',
        () {
      final text = _generateMarkdown(500);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      final blockCount = controller.document.blocks.length;
      expect(blockCount, greaterThan(100));

      // Place cursor roughly in the middle.
      final middleBlock = controller.document.blocks[blockCount ~/ 2];
      controller.selection = TextSelection.collapsed(
        offset: middleBlock.sourceStart + 1,
      );

      final span = controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );

      expect(span.children, isNotNull);
      expect(span.children!.length, equals(blockCount));

      // Blocks far from cursor should be plain (text-only TextSpan).
      final plainCount = _countPlainChildren(span);
      // With 500 blocks and ±50 radius, ~400 blocks should be plain.
      expect(plainCount, greaterThan(blockCount ~/ 2));
    });

    test('large doc, cursor at start: first 50 blocks styled, rest plain',
        () {
      final text = _generateMarkdown(500);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      controller.selection = const TextSelection.collapsed(offset: 0);

      final blockCount = controller.document.blocks.length;
      final span = controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );

      // Count plain blocks — those beyond the styled radius.
      final plainCount = _countPlainChildren(span);
      // With cursor at block 0 and radius 50, blocks 51+ should be plain.
      expect(plainCount, greaterThan(blockCount - 100));
    });

    test('large doc, cursor at end: last 50 blocks styled, rest plain', () {
      final text = _generateMarkdown(500);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      // Place cursor at the very end.
      controller.selection = TextSelection.collapsed(offset: text.length);

      final blockCount = controller.document.blocks.length;
      final span = controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );

      final plainCount = _countPlainChildren(span);
      expect(plainCount, greaterThan(blockCount - 100));
    });

    test('text concatenation matches controller.text (invariant preserved)',
        () {
      final text = _generateMarkdown(500);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      // Place cursor in the middle.
      final middleBlock =
          controller.document.blocks[controller.document.blocks.length ~/ 2];
      controller.selection = TextSelection.collapsed(
        offset: middleBlock.sourceStart + 1,
      );

      final span = controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );

      // Concatenate all text from the TextSpan tree.
      final concatenated = _extractText(span);
      expect(concatenated, equals(controller.text));
    });

    test('benchmark: buildTextSpan for 1K blocks with lazy optimization', () {
      final text = _generateMarkdown(1000);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      // Cursor at middle.
      final middleBlock =
          controller.document.blocks[controller.document.blocks.length ~/ 2];
      controller.selection = TextSelection.collapsed(
        offset: middleBlock.sourceStart + 1,
      );

      final sw = Stopwatch()..start();
      controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );
      sw.stop();

      // ignore: avoid_print
      print(
          'buildTextSpan 1K blocks (lazy): ${sw.elapsedMicroseconds}us');
    });
  });
}

/// Recursively extract all text from a TextSpan tree.
String _extractText(TextSpan span) {
  final buffer = StringBuffer();
  if (span.text != null) {
    buffer.write(span.text);
  }
  if (span.children != null) {
    for (final child in span.children!) {
      if (child is TextSpan) {
        buffer.write(_extractText(child));
      }
    }
  }
  return buffer.toString();
}
