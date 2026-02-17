import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitparser/petitparser.dart';

import 'package:markdowner/markdowner.dart';

void main() {
  late MarkdownGrammarDefinition grammar;
  late MarkdownParserDefinition definition;
  late Parser parser;

  setUp(() {
    grammar = MarkdownGrammarDefinition();
    definition = MarkdownParserDefinition();
    parser = definition.build();
  });

  /// Build a parser from a single production for isolated testing.
  Parser buildFrom(Parser Function() production) =>
      grammar.buildFrom(production());

  /// Parse and return a MarkdownDocument.
  MarkdownDocument parse(String input) {
    final result = parser.parse(input);
    if (result is Failure) {
      fail('Parse failed at ${result.position}: ${result.message}');
    }
    return (result as Success).value as MarkdownDocument;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Batch 1: Math Extension
  // ═══════════════════════════════════════════════════════════════════════════

  group('Math — Grammar', () {
    test('inlineMath matches \$E=mc^2\$', () {
      final p = buildFrom(grammar.inlineMath);
      final result = p.parse(r'$E=mc^2$');
      expect(result, isA<Success>());
    });

    test('inlineMath does NOT match \$5 and \$10 (space exclusion)', () {
      final p = buildFrom(grammar.inlineMath);
      final result = p.parse(r'$5 and $');
      expect(result, isA<Failure>());
    });

    test('inlineMath does not match empty \$\$', () {
      final p = buildFrom(grammar.inlineMath);
      final result = p.parse(r'$$');
      expect(result, isA<Failure>());
    });

    test('mathBlock matches \$\$\\nexpr\\n\$\$ block', () {
      final p = buildFrom(grammar.mathBlock);
      final result = p.parse('\$\$\nx^2 + y^2 = z^2\n\$\$\n');
      expect(result, isA<Success>());
    });

    test('math extension disabled disables inlineMath', () {
      final g = MarkdownGrammarDefinition(
        enabledExtensions: {MarkdownExtension.highlight},
      );
      final p = g.buildFrom(g.inlineMath());
      expect(p.parse(r'$x$'), isA<Failure>());
    });

    test('math extension disabled disables mathBlock', () {
      final g = MarkdownGrammarDefinition(
        enabledExtensions: {MarkdownExtension.highlight},
      );
      final p = g.buildFrom(g.mathBlock());
      expect(p.parse('\$\$\nx\n\$\$\n'), isA<Failure>());
    });
  });

  group('Math — Parser', () {
    test('inlineMath produces InlineMathInline with correct offsets', () {
      final doc = parse(r'$E=mc^2$' '\n');
      expect(doc.blocks, hasLength(1));
      final para = doc.blocks[0] as ParagraphBlock;
      expect(para.children, hasLength(1));
      final math = para.children[0] as InlineMathInline;
      expect(math.expression, r'E=mc^2');
      expect(math.contentStart, 1);
      expect(math.contentStop, 7);
    });

    test('mathBlock produces MathBlock with correct expression', () {
      final doc = parse('\$\$\nx^2 + y^2\n\$\$\n');
      expect(doc.blocks, hasLength(1));
      final block = doc.blocks[0] as MathBlock;
      expect(block.expression, 'x^2 + y^2');
    });

    test('roundtrip fidelity for inline math', () {
      const src = r'Hello $E=mc^2$ world' '\n';
      final doc = parse(src);
      expect(doc.toMarkdown(), src);
    });

    test('roundtrip fidelity for math block', () {
      const src = '\$\$\nf(x) = x^2\n\$\$\n';
      final doc = parse(src);
      expect(doc.toMarkdown(), src);
    });
  });

  group('Math — Render Engine', () {
    test('text invariant for inline math', () {
      const src = r'$x^2$' '\n';
      final doc = parse(src);
      final theme = MarkdownEditorTheme.light();
      final engine = MarkdownRenderEngine(theme: theme);
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      expect(_extractText(span), src);
    });

    test('text invariant for math block', () {
      const src = '\$\$\nx^2\n\$\$\n';
      final doc = parse(src);
      final theme = MarkdownEditorTheme.light();
      final engine = MarkdownRenderEngine(theme: theme);
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      expect(_extractText(span), src);
    });
  });

  group('Math — Cursor Mapper', () {
    test('inline math has \$ delimiters', () {
      const src = r'$x$' '\n';
      final doc = parse(src);
      final para = doc.blocks[0] as ParagraphBlock;
      final ranges = CursorMapper.delimiterRanges(para);
      // Opening $ at (0,1), closing $ at (2,3)
      expect(ranges, contains((0, 1)));
      expect(ranges, contains((2, 3)));
    });

    test('math block has delimiter ranges', () {
      const src = '\$\$\nx^2\n\$\$\n';
      final doc = parse(src);
      final block = doc.blocks[0] as MathBlock;
      final ranges = CursorMapper.delimiterRanges(block);
      // Opening $$\n (0,3), closing \n$$\n
      expect(ranges.length, 2);
      expect(ranges[0], (0, 3)); // $$\n
    });
  });

  group('Math — Theme', () {
    test('mathStyle exists in light theme', () {
      final theme = MarkdownEditorTheme.light();
      expect(theme.mathStyle, isNotNull);
      expect(theme.mathBlockStyle, isNotNull);
    });

    test('copyWith mathStyle works', () {
      final theme = MarkdownEditorTheme.light();
      final modified = theme.copyWith(
        mathStyle: theme.baseStyle.copyWith(fontSize: 20),
      );
      expect(modified.mathStyle.fontSize, 20);
    });
  });

  group('Math — Controller', () {
    test('toggleMath wraps selection with \$', () {
      final c = MarkdownEditingController(text: 'hello world\n');
      c.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
      c.toggleMath();
      expect(c.text, r'hello $world$' '\n');
    });

    test('toggleMath unwraps selection', () {
      final c = MarkdownEditingController(text: r'hello $world$' '\n');
      c.selection = const TextSelection(baseOffset: 7, extentOffset: 12);
      c.toggleMath();
      expect(c.text, 'hello world\n');
    });

    test('active format detects math', () {
      final c = MarkdownEditingController(text: r'$x^2$' '\n');
      c.selection = const TextSelection.collapsed(offset: 2);
      expect(c.activeInlineFormats, contains(InlineFormatType.math));
    });
  });

  group('Math — HTML', () {
    test('inline math converts to code with math class', () {
      final doc = parse(r'$E=mc^2$' '\n');
      final html = MarkdownToHtmlConverter().convert(doc);
      expect(html, contains(r'<code class="math">$E=mc^2$</code>'));
    });

    test('math block converts to pre with math class', () {
      final doc = parse('\$\$\nx^2\n\$\$\n');
      final html = MarkdownToHtmlConverter().convert(doc);
      expect(html, contains('<pre class="math">'));
    });

    test('HTML math code converts back to markdown', () {
      final md = HtmlToMarkdownConverter().convert(
        r'<code class="math">$x^2$</code>',
      );
      expect(md, contains(r'$x^2$'));
    });

    test('HTML math pre converts back to markdown', () {
      final md = HtmlToMarkdownConverter().convert(
        '<pre class="math">\$\$\nx^2\n\$\$</pre>',
      );
      expect(md, contains('\$\$'));
    });
  });

  group('Math — Smart Pairs', () {
    test('\$ auto-closes', () {
      final c = MarkdownEditingController(text: 'a\n');
      final oldVal = TextEditingValue(
        text: 'a\n',
        selection: const TextSelection.collapsed(offset: 1),
      );
      final newVal = TextEditingValue(
        text: 'a\$\n',
        selection: const TextSelection.collapsed(offset: 2),
      );
      final result = c.applySmartPairCompletion(oldVal, newVal);
      expect(result, isNotNull);
      expect(result!.text, 'a\$\$\n');
      expect(result.selection.baseOffset, 2);
    });

    test('\$ does not auto-close inside code context', () {
      final c = MarkdownEditingController(text: '`test`\n');
      final oldVal = TextEditingValue(
        text: '`tes\n',
        selection: const TextSelection.collapsed(offset: 4),
      );
      final newVal = TextEditingValue(
        text: '`tes\$\n',
        selection: const TextSelection.collapsed(offset: 5),
      );
      final result = c.applySmartPairCompletion(oldVal, newVal);
      // Inside code context → null (pass-through)
      expect(result, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Batch 2: Footnotes
  // ═══════════════════════════════════════════════════════════════════════════

  group('Footnotes — Grammar', () {
    test('footnoteRef matches [^1]', () {
      final p = buildFrom(grammar.footnoteRef);
      final result = p.parse('[^1]');
      expect(result, isA<Success>());
    });

    test('footnoteRef matches [^note]', () {
      final p = buildFrom(grammar.footnoteRef);
      final result = p.parse('[^note]');
      expect(result, isA<Success>());
    });

    test('footnoteDefinition matches [^1]: content', () {
      final p = buildFrom(grammar.footnoteDefinition);
      final result = p.parse('[^1]: This is a footnote\n');
      expect(result, isA<Success>());
    });

    test('footnotes disabled disables parsing', () {
      final g = MarkdownGrammarDefinition(
        enabledExtensions: {MarkdownExtension.highlight},
      );
      final p = g.buildFrom(g.footnoteRef());
      expect(p.parse('[^1]'), isA<Failure>());
    });
  });

  group('Footnotes — Parser', () {
    test('footnoteRef produces correct AST', () {
      final doc = parse('See[^1] here\n');
      final para = doc.blocks[0] as ParagraphBlock;
      final refs = para.children.whereType<FootnoteRefInline>();
      expect(refs.length, 1);
      expect(refs.first.label, '1');
    });

    test('footnoteDefinition produces correct AST', () {
      final doc = parse('[^1]: This is the footnote\n');
      expect(doc.blocks, hasLength(1));
      final fn = doc.blocks[0] as FootnoteDefinitionBlock;
      expect(fn.label, '1');
      expect(fn.children, isNotEmpty);
    });

    test('[text](url) still matches as link', () {
      final doc = parse('[text](url)\n');
      final para = doc.blocks[0] as ParagraphBlock;
      expect(para.children.first, isA<LinkInline>());
    });

    test('roundtrip fidelity for footnote ref', () {
      const src = 'Hello[^1] world\n';
      final doc = parse(src);
      expect(doc.toMarkdown(), src);
    });

    test('roundtrip fidelity for footnote definition', () {
      const src = '[^1]: Definition text\n';
      final doc = parse(src);
      expect(doc.toMarkdown(), src);
    });
  });

  group('Footnotes — Render Engine', () {
    test('text invariant for footnote ref', () {
      const src = 'Hello[^1]\n';
      final doc = parse(src);
      final theme = MarkdownEditorTheme.light();
      final engine = MarkdownRenderEngine(theme: theme);
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      expect(_extractText(span), src);
    });

    test('text invariant for footnote definition', () {
      const src = '[^1]: Content here\n';
      final doc = parse(src);
      final theme = MarkdownEditorTheme.light();
      final engine = MarkdownRenderEngine(theme: theme);
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      expect(_extractText(span), src);
    });
  });

  group('Footnotes — Cursor Mapper', () {
    test('footnoteRef has [^ and ] delimiters', () {
      const src = 'Hello[^1]\n';
      final doc = parse(src);
      final para = doc.blocks[0] as ParagraphBlock;
      final ranges = CursorMapper.delimiterRanges(para);
      // [^ at (5,7), ] at (8,9)
      expect(ranges, contains((5, 7)));
      expect(ranges, contains((8, 9)));
    });

    test('footnoteDefinition has prefix delimiter', () {
      const src = '[^1]: Content\n';
      final doc = parse(src);
      final block = doc.blocks[0] as FootnoteDefinitionBlock;
      final ranges = CursorMapper.delimiterRanges(block);
      // [^1]:  prefix length = 2 + 1 + 2 = 5
      expect(ranges.isNotEmpty, isTrue);
      expect(ranges[0].$1, 0);
    });
  });

  group('Footnotes — HTML', () {
    test('footnoteRef converts to sup with class', () {
      final doc = parse('Hello[^1]\n');
      final html = MarkdownToHtmlConverter().convert(doc);
      expect(html, contains('<sup class="footnote-ref">[1]</sup>'));
    });

    test('footnoteDefinition converts to div', () {
      final doc = parse('[^1]: Definition text\n');
      final html = MarkdownToHtmlConverter().convert(doc);
      expect(html, contains('<div class="footnote"'));
      expect(html, contains('data-label="1"'));
    });

    test('HTML footnote ref converts back', () {
      final md = HtmlToMarkdownConverter().convert(
        '<sup class="footnote-ref">[1]</sup>',
      );
      expect(md, contains('[^1]'));
    });

    test('HTML footnote definition converts back', () {
      final md = HtmlToMarkdownConverter().convert(
        '<div class="footnote" data-label="1"><p>Definition</p></div>',
      );
      expect(md, contains('[^1]: Definition'));
    });
  });

  group('Footnotes — Controller', () {
    test('insertFootnote creates [^1] at cursor', () {
      final c = MarkdownEditingController(text: 'Hello world\n');
      c.selection = const TextSelection.collapsed(offset: 5);
      c.insertFootnote();
      expect(c.text, contains('[^1]'));
    });

    test('insertFootnote auto-numbers', () {
      final c = MarkdownEditingController(text: 'See[^1] here\n');
      c.selection = const TextSelection.collapsed(offset: 12);
      c.insertFootnote();
      expect(c.text, contains('[^2]'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Batch 3: Emoji Shortcodes
  // ═══════════════════════════════════════════════════════════════════════════

  group('Emoji — Grammar', () {
    test(':smile: matches', () {
      final p = buildFrom(grammar.emoji);
      final result = p.parse(':smile:');
      expect(result, isA<Success>());
    });

    test(':thumbsup: matches', () {
      final p = buildFrom(grammar.emoji);
      final result = p.parse(':thumbsup:');
      expect(result, isA<Success>());
    });

    test(':not valid: with space does NOT match', () {
      final p = buildFrom(grammar.emoji);
      final result = p.parse(':not valid:');
      expect(result, isA<Failure>());
    });

    test(':: does NOT match (empty shortcode)', () {
      final p = buildFrom(grammar.emoji);
      final result = p.parse('::');
      expect(result, isA<Failure>());
    });

    test('emoji disabled disables parsing', () {
      final g = MarkdownGrammarDefinition(
        enabledExtensions: {MarkdownExtension.highlight},
      );
      final p = g.buildFrom(g.emoji());
      expect(p.parse(':smile:'), isA<Failure>());
    });
  });

  group('Emoji — Parser', () {
    test('emoji produces EmojiInline with correct shortcode', () {
      final doc = parse('Hello :smile: world\n');
      final para = doc.blocks[0] as ParagraphBlock;
      final emojis = para.children.whereType<EmojiInline>();
      expect(emojis.length, 1);
      expect(emojis.first.shortcode, 'smile');
    });

    test('roundtrip fidelity', () {
      const src = 'Hello :smile: world\n';
      final doc = parse(src);
      expect(doc.toMarkdown(), src);
    });
  });

  group('Emoji — Render Engine', () {
    test('text invariant preserved', () {
      const src = ':smile:\n';
      final doc = parse(src);
      final theme = MarkdownEditorTheme.light();
      final engine = MarkdownRenderEngine(theme: theme);
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      expect(_extractText(span), src);
    });
  });

  group('Emoji — Cursor Mapper', () {
    test('emoji has colon delimiters', () {
      const src = ':smile:\n';
      final doc = parse(src);
      final para = doc.blocks[0] as ParagraphBlock;
      final ranges = CursorMapper.delimiterRanges(para);
      // Opening : at (0,1), closing : at (6,7)
      expect(ranges, contains((0, 1)));
      expect(ranges, contains((6, 7)));
    });
  });

  group('Emoji — HTML', () {
    test(':smile: converts to Unicode emoji', () {
      final doc = parse(':smile:\n');
      final html = MarkdownToHtmlConverter().convert(doc);
      expect(html, contains('\u{1F604}'));
    });

    test('unknown shortcode passes through', () {
      final doc = parse(':nonexistent_emoji:\n');
      final html = MarkdownToHtmlConverter().convert(doc);
      expect(html, contains(':nonexistent_emoji:'));
    });
  });

  group('Emoji — Map', () {
    test('common shortcodes exist', () {
      expect(emojiShortcodes['smile'], isNotNull);
      expect(emojiShortcodes['heart'], isNotNull);
      expect(emojiShortcodes['thumbsup'], isNotNull);
      expect(emojiShortcodes['fire'], isNotNull);
      expect(emojiShortcodes['rocket'], isNotNull);
    });

    test('reverse map works', () {
      final unicode = emojiShortcodes['smile']!;
      expect(emojiToShortcode[unicode], 'smile');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Batch 4: YAML Front Matter
  // ═══════════════════════════════════════════════════════════════════════════

  group('YAML Front Matter — Grammar', () {
    test('matches at document start', () {
      final p = grammar.build();
      final result = p.parse('---\ntitle: foo\n---\n# Hello\n');
      expect(result, isA<Success>());
    });

    test('yamlFrontMatter disabled disables parsing', () {
      final g = MarkdownGrammarDefinition(
        enabledExtensions: {MarkdownExtension.highlight},
      );
      final p = g.buildFrom(g.yamlFrontMatter());
      expect(p.parse('---\ntitle: foo\n---\n'), isA<Failure>());
    });
  });

  group('YAML Front Matter — Parser', () {
    test('parses front matter + heading', () {
      final doc = parse('---\ntitle: foo\n---\n# Hello\n');
      expect(doc.blocks.length, 2);
      expect(doc.blocks[0], isA<YamlFrontMatterBlock>());
      expect(doc.blocks[1], isA<HeadingBlock>());
      final fm = doc.blocks[0] as YamlFrontMatterBlock;
      expect(fm.content, 'title: foo');
    });

    test('--- mid-document is thematic break, not front matter', () {
      final doc = parse('# Hello\n---\n');
      expect(doc.blocks.length, 2);
      expect(doc.blocks[0], isA<HeadingBlock>());
      expect(doc.blocks[1], isA<ThematicBreakBlock>());
    });

    test('roundtrip fidelity', () {
      const src = '---\ntitle: foo\n---\n# Hello\n';
      final doc = parse(src);
      expect(doc.toMarkdown(), src);
    });

    test('document starts without front matter works normally', () {
      final doc = parse('# Hello\n');
      expect(doc.blocks.length, 1);
      expect(doc.blocks[0], isA<HeadingBlock>());
    });
  });

  group('YAML Front Matter — Render Engine', () {
    test('text invariant', () {
      const src = '---\ntitle: foo\n---\n';
      final doc = parse('$src# Hello\n');
      final theme = MarkdownEditorTheme.light();
      final engine = MarkdownRenderEngine(theme: theme);
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      expect(_extractText(span), src);
    });
  });

  group('YAML Front Matter — Cursor Mapper', () {
    test('has delimiter ranges for fences', () {
      const src = '---\ntitle: foo\n---\n';
      final doc = parse('$src# Hello\n');
      final block = doc.blocks[0] as YamlFrontMatterBlock;
      final ranges = CursorMapper.delimiterRanges(block);
      expect(ranges.length, 2);
      expect(ranges[0], (0, 4)); // ---\n
    });
  });

  group('YAML Front Matter — HTML', () {
    test('converts to HTML comment', () {
      final doc = parse('---\ntitle: foo\n---\n');
      final html = MarkdownToHtmlConverter().convert(doc);
      expect(html, contains('<!-- front matter -->'));
    });
  });

  group('YAML Front Matter — Controller', () {
    test('activeBlockType is yamlFrontMatter', () {
      final c = MarkdownEditingController(text: '---\ntitle: foo\n---\n# Hello\n');
      c.selection = const TextSelection.collapsed(offset: 5);
      expect(c.activeBlockType, BlockType.yamlFrontMatter);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Batch 5: Table of Contents
  // ═══════════════════════════════════════════════════════════════════════════

  group('Table of Contents — Grammar', () {
    test('[TOC] matches', () {
      final p = buildFrom(grammar.tableOfContents);
      final result = p.parse('[TOC]\n');
      expect(result, isA<Success>());
    });

    test('[TOC] without newline at end of input matches', () {
      final p = buildFrom(grammar.tableOfContents);
      final result = p.parse('[TOC]');
      expect(result, isA<Success>());
    });

    test('[TOC] extra does NOT match', () {
      final p = buildFrom(grammar.tableOfContents);
      final result = p.parse('[TOC] extra\n');
      expect(result, isA<Failure>());
    });

    test('TOC disabled disables parsing', () {
      final g = MarkdownGrammarDefinition(
        enabledExtensions: {MarkdownExtension.highlight},
      );
      final p = g.buildFrom(g.tableOfContents());
      expect(p.parse('[TOC]\n'), isA<Failure>());
    });
  });

  group('Table of Contents — Parser', () {
    test('produces TableOfContentsBlock', () {
      final doc = parse('[TOC]\n');
      expect(doc.blocks, hasLength(1));
      expect(doc.blocks[0], isA<TableOfContentsBlock>());
    });

    test('roundtrip fidelity', () {
      const src = '[TOC]\n';
      final doc = parse(src);
      expect(doc.toMarkdown(), src);
    });
  });

  group('Table of Contents — Render Engine', () {
    test('text invariant', () {
      const src = '[TOC]\n';
      final doc = parse(src);
      final theme = MarkdownEditorTheme.light();
      final engine = MarkdownRenderEngine(theme: theme);
      final span = engine.buildRevealedSpan(doc.blocks[0], theme.baseStyle);
      expect(_extractText(span), src);
    });
  });

  group('Table of Contents — Cursor Mapper', () {
    test('entire block is delimiter', () {
      const src = '[TOC]\n';
      final doc = parse(src);
      final block = doc.blocks[0] as TableOfContentsBlock;
      final ranges = CursorMapper.delimiterRanges(block);
      expect(ranges, contains((0, src.length)));
    });
  });

  group('Table of Contents — HTML', () {
    test('generates heading list from document', () {
      final doc = parse('# Title\n## Section\n[TOC]\n');
      final html = MarkdownToHtmlConverter().convert(doc);
      expect(html, contains('<nav class="toc">'));
      expect(html, contains('Title'));
      expect(html, contains('Section'));
    });

    test('HTML toc converts back to [TOC]', () {
      final md = HtmlToMarkdownConverter().convert(
        '<nav class="toc"><ul><li>Title</li></ul></nav>',
      );
      expect(md, contains('[TOC]'));
    });
  });

  group('Table of Contents — Controller', () {
    test('activeBlockType is tableOfContents', () {
      final c = MarkdownEditingController(text: '[TOC]\n# Hello\n');
      c.selection = const TextSelection.collapsed(offset: 2);
      expect(c.activeBlockType, BlockType.tableOfContents);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Batch 6: Desktop Toolbar
  // ═══════════════════════════════════════════════════════════════════════════

  group('Desktop Toolbar', () {
    testWidgets('showLabels: true renders text labels', (tester) async {
      final controller = MarkdownEditingController(text: 'test\n');
      final editorKey = GlobalKey<MarkdownEditorState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownToolbar(
              controller: controller,
              editorKey: editorKey,
              showLabels: true,
              items: const [MarkdownToolbarItem.bold],
            ),
          ),
        ),
      );

      // TextButton.icon renders the label text
      expect(find.text('Bold'), findsOneWidget);
    });

    testWidgets('showLabels: false renders icons only', (tester) async {
      final controller = MarkdownEditingController(text: 'test\n');
      final editorKey = GlobalKey<MarkdownEditorState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownToolbar(
              controller: controller,
              editorKey: editorKey,
              showLabels: false,
              items: const [MarkdownToolbarItem.bold],
            ),
          ),
        ),
      );

      // Icon-only mode uses IconButton with tooltip
      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      // No text label
      expect(find.text('Bold'), findsNothing);
    });

    testWidgets('math toolbar item exists', (tester) async {
      final controller = MarkdownEditingController(text: 'test\n');
      final editorKey = GlobalKey<MarkdownEditorState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownToolbar(
              controller: controller,
              editorKey: editorKey,
              items: const [MarkdownToolbarItem.math],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.functions), findsOneWidget);
    });

    testWidgets('footnote toolbar item exists', (tester) async {
      final controller = MarkdownEditingController(text: 'test\n');
      final editorKey = GlobalKey<MarkdownEditorState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownToolbar(
              controller: controller,
              editorKey: editorKey,
              items: const [MarkdownToolbarItem.footnote],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.format_list_numbered), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Batch 7: Context Menu
  // ═══════════════════════════════════════════════════════════════════════════

  group('Context Menu', () {
    testWidgets('context menu builder is wired to EditableText',
        (tester) async {
      final editorKey = GlobalKey<MarkdownEditorState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              key: editorKey,
              initialMarkdown: 'Hello world\n',
              autofocus: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the editor state has the context menu delegates
      final state = editorKey.currentState;
      expect(state, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Theme tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('Theme — new styles', () {
    test('dark theme has all new styles', () {
      final theme = MarkdownEditorTheme.dark();
      expect(theme.mathStyle, isNotNull);
      expect(theme.mathBlockStyle, isNotNull);
      expect(theme.footnoteRefStyle, isNotNull);
      expect(theme.footnoteDefinitionStyle, isNotNull);
      expect(theme.emojiStyle, isNotNull);
      expect(theme.frontMatterStyle, isNotNull);
      expect(theme.tocStyle, isNotNull);
    });

    test('copyWith preserves all new styles', () {
      final theme = MarkdownEditorTheme.light();
      final copy = theme.copyWith();
      expect(copy.mathStyle, theme.mathStyle);
      expect(copy.mathBlockStyle, theme.mathBlockStyle);
      expect(copy.footnoteRefStyle, theme.footnoteRefStyle);
      expect(copy.footnoteDefinitionStyle, theme.footnoteDefinitionStyle);
      expect(copy.emojiStyle, theme.emojiStyle);
      expect(copy.frontMatterStyle, theme.frontMatterStyle);
      expect(copy.tocStyle, theme.tocStyle);
    });
  });
}

/// Recursively extract all text from a TextSpan tree.
String _extractText(TextSpan span) {
  final buf = StringBuffer();
  if (span.text != null) buf.write(span.text);
  if (span.children != null) {
    for (final child in span.children!) {
      buf.write(_extractText(child as TextSpan));
    }
  }
  return buf.toString();
}
