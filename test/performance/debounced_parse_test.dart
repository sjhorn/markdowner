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

void main() {
  group('debounced parsing', () {
    test('small doc (<200 blocks) parses immediately, no debounce', () {
      final text = _generateMarkdown(100);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      expect(controller.document.blocks.length, lessThan(200));

      // Simulate an edit — should parse immediately.
      final edited = '${text}X';
      controller.value = TextEditingValue(
        text: edited,
        selection: TextSelection.collapsed(offset: edited.length),
      );

      // Document should already be updated (no debounce).
      expect(controller.document.blocks, isNotEmpty);
      expect(controller.isDebouncing, isFalse);
    });

    test('large doc (>200 blocks) debounces parsing', () {
      final text = _generateMarkdown(2000);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      expect(controller.document.blocks.length, greaterThan(200));
      final blockCountBefore = controller.document.blocks.length;

      // Simulate an edit on a large doc.
      final edited = '${text}Y';
      controller.value = TextEditingValue(
        text: edited,
        selection: TextSelection.collapsed(offset: edited.length),
      );

      // Should be debouncing — document may still have old block count.
      expect(controller.isDebouncing, isTrue);
      // Block count should still reflect the old parse
      // (or 0 — depends on implementation, but debouncing should be true).
      expect(controller.document.blocks.length, equals(blockCountBefore));
    });

    test('after debounce fires, document is re-parsed', () async {
      final text = _generateMarkdown(2000);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      // Edit to trigger debounce.
      final edited = '${text}Z';
      controller.value = TextEditingValue(
        text: edited,
        selection: TextSelection.collapsed(offset: edited.length),
      );

      expect(controller.isDebouncing, isTrue);

      // Wait for debounce to fire (150ms + margin).
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(controller.isDebouncing, isFalse);
      // Document should now reflect the edited text.
      expect(controller.document.blocks, isNotEmpty);
    });

    test('buildTextSpan returns unstyled span during debounce', () {
      final text = _generateMarkdown(2000);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      controller.selection = const TextSelection.collapsed(offset: 0);

      // Trigger debounce.
      final edited = '${text}W';
      controller.value = TextEditingValue(
        text: edited,
        selection: TextSelection.collapsed(offset: edited.length),
      );

      expect(controller.isDebouncing, isTrue);

      // buildTextSpan during debounce should return a single unstyled span.
      final span = controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );

      // During debounce, should be a single TextSpan with the full text.
      expect(span.text, equals(edited));
      expect(span.children, isNull);
    });

    test('buildTextSpan returns styled spans after debounce completes',
        () async {
      final text = _generateMarkdown(2000);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      controller.selection = const TextSelection.collapsed(offset: 0);

      // Trigger debounce.
      final edited = '${text}V';
      controller.value = TextEditingValue(
        text: edited,
        selection: TextSelection.collapsed(offset: edited.length),
      );

      // Wait for debounce.
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(controller.isDebouncing, isFalse);

      final span = controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );

      // After debounce, should have children (styled spans per block).
      expect(span.children, isNotNull);
      expect(span.children, isNotEmpty);
    });

    test('dispose cancels debounce timer', () {
      final text = _generateMarkdown(2000);
      final controller = MarkdownEditingController(text: text);

      // Trigger debounce.
      final edited = '${text}U';
      controller.value = TextEditingValue(
        text: edited,
        selection: TextSelection.collapsed(offset: edited.length),
      );

      expect(controller.isDebouncing, isTrue);

      // Dispose should not throw.
      controller.dispose();
    });
  });
}
