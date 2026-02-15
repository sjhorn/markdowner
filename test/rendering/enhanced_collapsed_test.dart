import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/core/markdown_nodes.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/rendering/markdown_render_engine.dart';
import 'package:markdowner/src/theme/markdown_editor_theme.dart';

void main() {
  late MarkdownRenderEngine engine;
  late MarkdownEditorTheme theme;
  late TextStyle baseStyle;

  setUp(() {
    theme = MarkdownEditorTheme.light();
    engine = MarkdownRenderEngine(theme: theme);
    baseStyle = theme.baseStyle;
  });

  /// Helper to collect all TextSpan leaves from a span tree.
  List<TextSpan> collectLeaves(TextSpan span) {
    final leaves = <TextSpan>[];
    void walk(InlineSpan s) {
      if (s is TextSpan) {
        if (s.children == null || s.children!.isEmpty) {
          leaves.add(s);
        } else {
          for (final child in s.children!) {
            walk(child);
          }
        }
      }
    }
    walk(span);
    return leaves;
  }

  /// Helper to concatenate all text from a span tree.
  String collectText(TextSpan span) {
    final buf = StringBuffer();
    void walk(InlineSpan s) {
      if (s is TextSpan) {
        if (s.text != null) buf.write(s.text);
        if (s.children != null) {
          for (final child in s.children!) {
            walk(child);
          }
        }
      }
    }
    walk(span);
    return buf.toString();
  }

  group('thematic break collapsed rendering', () {
    test('uses thematicBreakStyle in collapsed mode', () {
      final controller = MarkdownEditingController(text: '---\n');
      addTearDown(controller.dispose);

      // Place cursor outside the block (end of text).
      controller.selection = const TextSelection.collapsed(offset: 4);

      final block = controller.document.blocks[0];
      expect(block, isA<ThematicBreakBlock>());

      final span = engine.buildCollapsedSpan(block, baseStyle);
      final leaves = collectLeaves(span);

      // The thematic break text should use thematicBreakStyle.
      final breakLeaf = leaves.firstWhere((l) => l.text == '---');
      expect(breakLeaf.style, theme.thematicBreakStyle);
    });

    test('uses delimiter style in revealed mode', () {
      final controller = MarkdownEditingController(text: '---\n');
      addTearDown(controller.dispose);

      final block = controller.document.blocks[0];
      final span = engine.buildRevealedSpan(block, baseStyle);
      final leaves = collectLeaves(span);

      // In revealed mode, should use syntaxDelimiterStyle.
      final breakLeaf = leaves.firstWhere((l) => l.text != null && l.text!.contains('---'));
      expect(breakLeaf.style, theme.syntaxDelimiterStyle);
    });

    test('preserves source text in collapsed mode', () {
      final controller = MarkdownEditingController(text: '---\n');
      addTearDown(controller.dispose);

      final block = controller.document.blocks[0];
      final span = engine.buildCollapsedSpan(block, baseStyle);

      expect(collectText(span), '---\n');
    });
  });

  group('code block collapsed rendering', () {
    test('hides fences in collapsed mode', () {
      final controller = MarkdownEditingController(text: '```\ncode\n```\n');
      addTearDown(controller.dispose);

      final block = controller.document.blocks[0];
      expect(block, isA<FencedCodeBlock>());

      final span = engine.buildCollapsedSpan(block, baseStyle);
      final leaves = collectLeaves(span);

      // Fence lines should be hidden (hiddenSyntaxStyle).
      final fenceLeaves = leaves.where(
          (l) => l.text != null && l.text!.contains('```'));
      expect(fenceLeaves, isNotEmpty);
      for (final leaf in fenceLeaves) {
        expect(leaf.style, theme.hiddenSyntaxStyle);
      }

      // Code content should use codeBlockStyle.
      final codeLeaf = leaves.firstWhere(
          (l) => l.text != null && l.text!.contains('code'));
      expect(codeLeaf.style, theme.codeBlockStyle);
    });

    test('preserves source text in collapsed mode', () {
      final controller = MarkdownEditingController(text: '```dart\nhello()\n```\n');
      addTearDown(controller.dispose);

      final block = controller.document.blocks[0];
      final span = engine.buildCollapsedSpan(block, baseStyle);

      expect(collectText(span), '```dart\nhello()\n```\n');
    });
  });

  group('blockquote collapsed rendering', () {
    test('uses blockquoteMarkerStyle for > prefix in collapsed mode', () {
      final controller = MarkdownEditingController(text: '> quoted\n');
      addTearDown(controller.dispose);

      final block = controller.document.blocks[0];
      expect(block, isA<BlockquoteBlock>());

      final span = engine.buildCollapsedSpan(block, baseStyle);
      final leaves = collectLeaves(span);

      // The "> " prefix should use blockquoteMarkerStyle.
      final markerLeaf = leaves.firstWhere((l) => l.text == '> ');
      expect(markerLeaf.style, theme.blockquoteMarkerStyle);
    });

    test('uses blockquoteStyle for content in collapsed mode', () {
      final controller = MarkdownEditingController(text: '> quoted\n');
      addTearDown(controller.dispose);

      final block = controller.document.blocks[0];
      final span = engine.buildCollapsedSpan(block, baseStyle);
      final leaves = collectLeaves(span);

      // The content should use blockquoteStyle.
      final contentLeaf = leaves.firstWhere((l) => l.text == 'quoted');
      expect(contentLeaf.style, theme.blockquoteStyle);
    });

    test('preserves source text in collapsed mode', () {
      final controller = MarkdownEditingController(text: '> quoted text\n');
      addTearDown(controller.dispose);

      final block = controller.document.blocks[0];
      final span = engine.buildCollapsedSpan(block, baseStyle);

      expect(collectText(span), '> quoted text\n');
    });
  });

  group('task checkbox collapsed rendering', () {
    test('uses taskUncheckedStyle for [ ] in collapsed mode', () {
      final controller = MarkdownEditingController(text: '- [ ] task\n');
      addTearDown(controller.dispose);

      final block = controller.document.blocks[0];
      expect(block, isA<UnorderedListItemBlock>());
      expect((block as UnorderedListItemBlock).isTask, true);
      expect(block.taskChecked, false);

      final span = engine.buildCollapsedSpan(block, baseStyle);
      final leaves = collectLeaves(span);

      // Find the leaf containing the checkbox text.
      final checkboxLeaf = leaves.firstWhere(
          (l) => l.text != null && l.text!.contains('[ ]'));
      expect(checkboxLeaf.style, theme.taskUncheckedStyle);
    });

    test('uses taskCheckedStyle for [x] in collapsed mode', () {
      final controller = MarkdownEditingController(text: '- [x] done\n');
      addTearDown(controller.dispose);

      final block = controller.document.blocks[0];
      expect(block, isA<UnorderedListItemBlock>());
      expect((block as UnorderedListItemBlock).isTask, true);
      expect(block.taskChecked, true);

      final span = engine.buildCollapsedSpan(block, baseStyle);
      final leaves = collectLeaves(span);

      final checkboxLeaf = leaves.firstWhere(
          (l) => l.text != null && l.text!.contains('[x]'));
      expect(checkboxLeaf.style, theme.taskCheckedStyle);
    });

    test('preserves source text in collapsed mode', () {
      final controller = MarkdownEditingController(text: '- [ ] task item\n');
      addTearDown(controller.dispose);

      final block = controller.document.blocks[0];
      final span = engine.buildCollapsedSpan(block, baseStyle);

      expect(collectText(span), '- [ ] task item\n');
    });
  });

  group('toggleTaskCheckbox', () {
    test('toggles [ ] to [x] in source text', () {
      final controller = MarkdownEditingController(text: '- [ ] task\n');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 8);

      controller.toggleTaskCheckbox(0);

      expect(controller.text, '- [x] task\n');
    });

    test('toggles [x] to [ ] in source text', () {
      final controller = MarkdownEditingController(text: '- [x] done\n');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 8);

      controller.toggleTaskCheckbox(0);

      expect(controller.text, '- [ ] done\n');
    });

    test('toggles ordered list task checkbox', () {
      final controller = MarkdownEditingController(text: '1. [ ] task\n');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 8);

      controller.toggleTaskCheckbox(0);

      expect(controller.text, '1. [x] task\n');
    });

    test('does nothing for non-task block', () {
      final controller = MarkdownEditingController(text: '- item\n');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 4);

      controller.toggleTaskCheckbox(0);

      expect(controller.text, '- item\n');
    });

    test('does nothing for invalid block index', () {
      final controller = MarkdownEditingController(text: '- [ ] task\n');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 4);

      controller.toggleTaskCheckbox(99);

      expect(controller.text, '- [ ] task\n');
    });

    test('works with multiple list items', () {
      final controller = MarkdownEditingController(
          text: '- [ ] first\n- [x] second\n- [ ] third\n');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 15);

      // Toggle the second item (index 1).
      controller.toggleTaskCheckbox(1);

      expect(controller.text, '- [ ] first\n- [ ] second\n- [ ] third\n');
    });
  });
}
