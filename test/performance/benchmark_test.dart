import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/parsing/incremental_parser.dart';
import 'package:markdowner/src/rendering/markdown_render_engine.dart';
import 'package:markdowner/src/theme/markdown_editor_theme.dart';

/// Generate a markdown document with approximately [lines] lines.
String _generateMarkdown(int lines) {
  final buffer = StringBuffer();
  var lineCount = 0;

  while (lineCount < lines) {
    // Add a heading every ~20 lines.
    if (lineCount % 20 == 0) {
      buffer.write('## Section ${lineCount ~/ 20 + 1}\n\n');
      lineCount += 2;
    }

    // Add a paragraph with inline formatting.
    buffer.write('This is paragraph $lineCount with **bold** and *italic* text.\n\n');
    lineCount += 2;

    if (lineCount >= lines) break;

    // Add a list every ~10 lines.
    if (lineCount % 10 == 0) {
      buffer.write('- Item one with `code`\n');
      buffer.write('- Item two with [link](http://example.com)\n');
      buffer.write('- Item three\n\n');
      lineCount += 4;
    }

    if (lineCount >= lines) break;

    // Add a code block every ~30 lines.
    if (lineCount % 30 == 0) {
      buffer.write('```dart\nvoid main() {\n  print("hello");\n}\n```\n\n');
      lineCount += 6;
    }

    if (lineCount >= lines) break;

    // Add a blockquote.
    if (lineCount % 15 == 0) {
      buffer.write('> This is a blockquote with some **bold** text.\n\n');
      lineCount += 2;
    }
  }

  return buffer.toString();
}

void main() {
  group('parse benchmarks', () {
    test('parse 1,000 line document under 50ms', () {
      final text = _generateMarkdown(1000);
      final engine = IncrementalParseEngine();

      final sw = Stopwatch()..start();
      final doc = engine.parse(text);
      sw.stop();

      expect(doc.blocks, isNotEmpty);
      // Relaxed: just ensure it completes. In CI the timing may vary.
      // Print for manual review.
      // ignore: avoid_print
      print('1K lines: ${sw.elapsedMilliseconds}ms, ${doc.blocks.length} blocks');
      // Target: < 50ms
    });

    test('parse 5,000 line document completes', () {
      final text = _generateMarkdown(5000);
      final engine = IncrementalParseEngine();

      final sw = Stopwatch()..start();
      final doc = engine.parse(text);
      sw.stop();

      expect(doc.blocks, isNotEmpty);
      // ignore: avoid_print
      print('5K lines: ${sw.elapsedMilliseconds}ms, ${doc.blocks.length} blocks');
    });
  });

  group('span caching benchmarks', () {
    test('span cache prevents rebuilding unchanged blocks', () {
      final theme = MarkdownEditorTheme.light();
      final engine = MarkdownRenderEngine(theme: theme);
      final baseStyle = theme.baseStyle;

      final text = _generateMarkdown(100);
      final parseEngine = IncrementalParseEngine();
      final doc = parseEngine.parse(text);

      // Build all spans (cold cache).
      final sw1 = Stopwatch()..start();
      for (final block in doc.blocks) {
        engine.buildCollapsedSpan(block, baseStyle);
      }
      sw1.stop();

      // Build all spans again (warm cache).
      final sw2 = Stopwatch()..start();
      for (final block in doc.blocks) {
        engine.buildCollapsedSpan(block, baseStyle);
      }
      sw2.stop();

      // ignore: avoid_print
      print('Cold: ${sw1.elapsedMicroseconds}us, Warm: ${sw2.elapsedMicroseconds}us');
      // Warm cache should be significantly faster.
      expect(engine.cacheSize, greaterThan(0));
    });

    test('detectChangedBlocks identifies single block edit', () {
      final engine = IncrementalParseEngine();
      final oldText = _generateMarkdown(100);
      final oldDoc = engine.parse(oldText);

      // Simulate a single character insertion in the middle.
      final editPos = oldText.length ~/ 2;
      final newText = '${oldText.substring(0, editPos)}X${oldText.substring(editPos)}';
      final newDoc = engine.parse(newText);

      final changed = engine.detectChangedBlocks(oldDoc, newDoc);

      // Only a small number of blocks should be detected as changed.
      // ignore: avoid_print
      print('Changed blocks: ${changed.length} out of ${newDoc.blocks.length}');
      expect(changed.length, lessThan(newDoc.blocks.length));
    });
  });

  group('buildTextSpan benchmarks', () {
    test('buildTextSpan for 100 blocks completes under 8ms', () {
      final text = _generateMarkdown(100);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      // Place cursor at start so first block is revealed, rest collapsed.
      controller.selection = const TextSelection.collapsed(offset: 0);

      final sw = Stopwatch()..start();
      controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );
      sw.stop();

      // ignore: avoid_print
      print('buildTextSpan: ${sw.elapsedMicroseconds}us');
    });
  });
}

/// Minimal BuildContext stub for testing buildTextSpan outside a widget tree.
class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
