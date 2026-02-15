import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/parsing/incremental_parser.dart';

void main() {
  late IncrementalParseEngine engine;

  setUp(() {
    engine = IncrementalParseEngine();
  });

  group('IncrementalParseEngine.parse', () {
    test('parses empty text', () {
      final doc = engine.parse('');
      expect(doc.blocks, isEmpty);
    });

    test('parses simple paragraph', () {
      final doc = engine.parse('Hello\n');
      expect(doc.blocks.length, 1);
    });

    test('parses multiple blocks', () {
      final doc = engine.parse('# Title\n\nHello\n');
      expect(doc.blocks.length, 3);
    });

    test('roundtrips correctly', () {
      const text = '# Title\n\nParagraph **bold**\n\n- item\n';
      final doc = engine.parse(text);
      expect(doc.toMarkdown(), text);
    });
  });

  group('detectChangedBlocks', () {
    test('returns empty set for identical documents', () {
      const text = '# Title\n\nHello\n';
      final doc1 = engine.parse(text);
      final doc2 = engine.parse(text);
      expect(engine.detectChangedBlocks(doc1, doc2), isEmpty);
    });

    test('detects single changed block in middle', () {
      const oldText = '# Title\n\nHello\n\nWorld\n';
      const newText = '# Title\n\nHello World\n\nWorld\n';
      final oldDoc = engine.parse(oldText);
      final newDoc = engine.parse(newText);
      final changed = engine.detectChangedBlocks(oldDoc, newDoc);

      // The second content block changed (paragraph "Hello" → "Hello World")
      expect(changed, isNotEmpty);
      // Block index 2 is the paragraph that changed.
      expect(changed.contains(2), true);
    });

    test('detects first block changed', () {
      const oldText = '# Title\n\nHello\n';
      const newText = '## Title\n\nHello\n';
      final oldDoc = engine.parse(oldText);
      final newDoc = engine.parse(newText);
      final changed = engine.detectChangedBlocks(oldDoc, newDoc);

      expect(changed.contains(0), true);
    });

    test('detects last block changed', () {
      const oldText = '# Title\n\nHello\n';
      const newText = '# Title\n\nWorld\n';
      final oldDoc = engine.parse(oldText);
      final newDoc = engine.parse(newText);
      final changed = engine.detectChangedBlocks(oldDoc, newDoc);

      expect(changed.contains(2), true);
    });

    test('detects added block', () {
      const oldText = '# Title\n\nHello\n';
      const newText = '# Title\n\nHello\n\nWorld\n';
      final oldDoc = engine.parse(oldText);
      final newDoc = engine.parse(newText);
      final changed = engine.detectChangedBlocks(oldDoc, newDoc);

      // New blocks should be marked as changed.
      expect(changed, isNotEmpty);
    });

    test('returns empty for removed blocks when remaining match', () {
      const oldText = '# Title\n\nHello\n\nWorld\n';
      const newText = '# Title\n\nHello\n';
      final oldDoc = engine.parse(oldText);
      final newDoc = engine.parse(newText);
      final changed = engine.detectChangedBlocks(oldDoc, newDoc);

      // All blocks in newDoc match the prefix of oldDoc, so no blocks
      // in the new document are "changed" — the removed blocks simply
      // don't exist in newDoc.
      expect(changed, isEmpty);
    });

    test('detects changed block when removal alters surrounding text', () {
      const oldText = '# Title\n\nHello\n\nWorld\n';
      const newText = '# Title\n\nHelloWorld\n';
      final oldDoc = engine.parse(oldText);
      final newDoc = engine.parse(newText);
      final changed = engine.detectChangedBlocks(oldDoc, newDoc);

      // The merged paragraph "HelloWorld" is different from "Hello".
      expect(changed, isNotEmpty);
    });

    test('handles single block document changes', () {
      const oldText = 'Hello\n';
      const newText = 'Hello World\n';
      final oldDoc = engine.parse(oldText);
      final newDoc = engine.parse(newText);
      final changed = engine.detectChangedBlocks(oldDoc, newDoc);

      expect(changed.contains(0), true);
    });

    test('returns empty for exact same parse result', () {
      const text = '- item 1\n- item 2\n';
      final doc = engine.parse(text);
      final changed = engine.detectChangedBlocks(doc, doc);
      expect(changed, isEmpty);
    });

    test('detects change when typing in one block of many', () {
      const oldText = '# Title\n\nFirst paragraph.\n\nSecond paragraph.\n\n- list item\n';
      const newText = '# Title\n\nFirst paragraph!\n\nSecond paragraph.\n\n- list item\n';
      final oldDoc = engine.parse(oldText);
      final newDoc = engine.parse(newText);
      final changed = engine.detectChangedBlocks(oldDoc, newDoc);

      // Only the "First paragraph" block should change.
      expect(changed.length, 1);
      expect(changed.contains(2), true);
    });
  });
}
