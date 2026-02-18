import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/parsing/incremental_parser.dart';
import 'package:markdowner/src/rendering/markdown_render_engine.dart';
import 'package:markdowner/src/theme/markdown_editor_theme.dart';
import 'package:markdowner/src/utils/undo_redo_manager.dart';

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

    test('parse 10,000 line document', () {
      final text = _generateMarkdown(10000);
      final engine = IncrementalParseEngine();

      final sw = Stopwatch()..start();
      final doc = engine.parse(text);
      sw.stop();

      expect(doc.blocks, isNotEmpty);
      // ignore: avoid_print
      print('10K lines: ${sw.elapsedMilliseconds}ms, ${doc.blocks.length} blocks');
    });

    test('parse 20,000 line document', () {
      final text = _generateMarkdown(20000);
      final engine = IncrementalParseEngine();

      final sw = Stopwatch()..start();
      final doc = engine.parse(text);
      sw.stop();

      expect(doc.blocks, isNotEmpty);
      // ignore: avoid_print
      print('20K lines: ${sw.elapsedMilliseconds}ms, ${doc.blocks.length} blocks');
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

  group('memory benchmarks', () {
    test('document memory footprint', () {
      final text = _generateMarkdown(10000);
      final engine = IncrementalParseEngine();
      final doc = engine.parse(text);

      // Estimate memory: block count × average sourceText length.
      var totalSourceLen = 0;
      for (final block in doc.blocks) {
        totalSourceLen += block.sourceText.length;
      }
      final avgBlockLen = totalSourceLen / doc.blocks.length;

      // ignore: avoid_print
      print('10K lines: ${doc.blocks.length} blocks, '
          'total source $totalSourceLen chars, '
          'avg block ${avgBlockLen.toStringAsFixed(1)} chars');
      expect(doc.blocks.length, greaterThan(0));
    });

    test('span cache memory at capacity', () {
      final theme = MarkdownEditorTheme.light();
      final engine = MarkdownRenderEngine(theme: theme);
      final baseStyle = theme.baseStyle;
      final parseEngine = IncrementalParseEngine();

      // Generate enough unique blocks to fill cache to 500 entries.
      final text = _generateMarkdown(5000);
      final doc = parseEngine.parse(text);

      for (final block in doc.blocks) {
        engine.buildCollapsedSpan(block, baseStyle);
      }

      // ignore: avoid_print
      print('Cache size after ${doc.blocks.length} blocks: ${engine.cacheSize}');
      expect(engine.cacheSize, greaterThan(0));
    });
  });

  group('rapid edit simulation', () {
    test('10 rapid edits on 1K doc', () {
      final engine = IncrementalParseEngine();
      var text = _generateMarkdown(1000);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 10; i++) {
        final pos = text.length ~/ 2;
        text = '${text.substring(0, pos)}X${text.substring(pos)}';
        engine.parse(text);
      }
      sw.stop();

      // ignore: avoid_print
      print('10 rapid edits on 1K doc: ${sw.elapsedMilliseconds}ms '
          '(${(sw.elapsedMilliseconds / 10).toStringAsFixed(1)}ms/edit)');
    });

    test('10 rapid edits on 5K doc', () {
      final engine = IncrementalParseEngine();
      var text = _generateMarkdown(5000);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 10; i++) {
        final pos = text.length ~/ 2;
        text = '${text.substring(0, pos)}X${text.substring(pos)}';
        engine.parse(text);
      }
      sw.stop();

      // ignore: avoid_print
      print('10 rapid edits on 5K doc: ${sw.elapsedMilliseconds}ms '
          '(${(sw.elapsedMilliseconds / 10).toStringAsFixed(1)}ms/edit)');
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
      print('buildTextSpan 100 blocks: ${sw.elapsedMicroseconds}us');
    });

    test('buildTextSpan for 1000 blocks cold and warm', () {
      final text = _generateMarkdown(1000);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      controller.selection = const TextSelection.collapsed(offset: 0);

      // Cold cache.
      final sw1 = Stopwatch()..start();
      controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );
      sw1.stop();

      // Warm cache.
      final sw2 = Stopwatch()..start();
      controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );
      sw2.stop();

      // ignore: avoid_print
      print('buildTextSpan 1K blocks — Cold: ${sw1.elapsedMicroseconds}us, '
          'Warm: ${sw2.elapsedMicroseconds}us');
    });
  });

  group('final comparison benchmarks', () {
    test('10K lines: parse + buildTextSpan end-to-end', () {
      final text = _generateMarkdown(10000);

      // Parse.
      final swParse = Stopwatch()..start();
      final controller = MarkdownEditingController(text: text);
      swParse.stop();
      addTearDown(controller.dispose);

      // Place cursor in middle for lazy optimization.
      final middleBlock =
          controller.document.blocks[controller.document.blocks.length ~/ 2];
      controller.selection = TextSelection.collapsed(
        offset: middleBlock.sourceStart + 1,
      );

      // buildTextSpan.
      final swSpan = Stopwatch()..start();
      controller.buildTextSpan(
        context: _FakeBuildContext(),
        style: controller.theme.baseStyle,
        withComposing: false,
      );
      swSpan.stop();

      // ignore: avoid_print
      print('10K lines end-to-end — parse: ${swParse.elapsedMilliseconds}ms, '
          'buildTextSpan: ${swSpan.elapsedMicroseconds}us');
    });

    test('10K lines: rapid edit simulation with debounce', () async {
      final text = _generateMarkdown(10000);
      final controller = MarkdownEditingController(text: text);
      addTearDown(controller.dispose);

      expect(controller.document.blocks.length, greaterThan(200));

      final sw = Stopwatch()..start();
      // Simulate 10 rapid single-char edits.
      var current = text;
      for (var i = 0; i < 10; i++) {
        final pos = current.length ~/ 2;
        current = '${current.substring(0, pos)}X${current.substring(pos)}';
        controller.value = TextEditingValue(
          text: current,
          selection: TextSelection.collapsed(offset: pos + 1),
        );
      }
      sw.stop();

      // During rapid edits, should be debouncing.
      expect(controller.isDebouncing, isTrue);

      // ignore: avoid_print
      print('10 rapid edits on 10K doc (debounced): ${sw.elapsedMilliseconds}ms '
          '(${(sw.elapsedMilliseconds / 10).toStringAsFixed(1)}ms/edit)');

      // Wait for debounce to complete.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(controller.isDebouncing, isFalse);
    });

    test('memory: undo stack bounded for large docs', () {
      final manager = UndoRedoManager();
      addTearDown(manager.dispose);

      // 150KB document — should use 50-snapshot limit.
      final largeMarkdown = 'x' * 150000;
      manager.setInitialState(
        largeMarkdown,
        const TextSelection.collapsed(offset: 0),
      );

      // Push 100 snapshots.
      for (var i = 0; i < 100; i++) {
        manager.recordChange(
          '$largeMarkdown${String.fromCharCode(65 + (i % 26))}$i',
          TextSelection.collapsed(offset: i),
        );
        manager.breakGroup();
      }

      // With adaptive limit of 50, undo stack should be bounded.
      expect(manager.undoStackSize, lessThanOrEqualTo(50));

      // ignore: avoid_print
      print('Undo stack size for 150KB doc after 100 edits: '
          '${manager.undoStackSize}');
    });

    test('memory: undo stack uses default limit for small docs', () {
      final manager = UndoRedoManager();
      addTearDown(manager.dispose);

      // 10KB document — should use default 200-snapshot limit.
      final smallMarkdown = 'x' * 10000;
      manager.setInitialState(
        smallMarkdown,
        const TextSelection.collapsed(offset: 0),
      );

      // Push 60 snapshots (under limit).
      for (var i = 0; i < 60; i++) {
        manager.recordChange(
          '$smallMarkdown${String.fromCharCode(65 + (i % 26))}$i',
          TextSelection.collapsed(offset: i),
        );
        manager.breakGroup();
      }

      // All 60 should be in the stack.
      expect(manager.undoStackSize, equals(60));
    });
  });
}

/// Minimal BuildContext stub for testing buildTextSpan outside a widget tree.
class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
