// ignore_for_file: avoid_print

// Demonstrates parsing markdown into an AST using the markdowner parser.
//
// Run with: `dart run example/parse_demo.dart`
import 'package:markdowner/markdowner.dart';
import 'package:petitparser/petitparser.dart';

const sampleMarkdown = '''
# Welcome to Markdowner

This is a **bold** statement with *italic* flair.

## Features

Supports ***bold italic***, `inline code`, and ~~strikethrough~~.
Escaped chars like \\* and \\# are handled too.

---

That was a thematic break above.
''';

void main() {
  final parser = MarkdownParserDefinition().build();
  final result = parser.parse(sampleMarkdown);

  if (result is Failure) {
    print('Parse failed at position ${result.position}: ${result.message}');
    return;
  }

  final doc = (result as Success).value as MarkdownDocument;
  print('Parsed ${doc.blocks.length} blocks:\n');

  for (var i = 0; i < doc.blocks.length; i++) {
    final block = doc.blocks[i];
    print('[$i] ${_describeBlock(block)}');
  }
}

String _describeBlock(MarkdownBlock block) {
  return switch (block) {
    HeadingBlock() =>
      'HeadingBlock(level=${block.level}, '
          'children=[${block.children.map(_describeInline).join(', ')}], '
          'source=${block.sourceStart}..${block.sourceStop})',
    ParagraphBlock() =>
      'ParagraphBlock('
          'children=[${block.children.map(_describeInline).join(', ')}], '
          'source=${block.sourceStart}..${block.sourceStop})',
    ThematicBreakBlock() =>
      'ThematicBreakBlock(marker="${block.marker}", '
          'source=${block.sourceStart}..${block.sourceStop})',
    BlankLineBlock() =>
      'BlankLineBlock(source=${block.sourceStart}..${block.sourceStop})',
    FencedCodeBlock() =>
      'FencedCodeBlock(fence="${block.fence}", '
          'language=${block.language ?? "null"}, '
          'source=${block.sourceStart}..${block.sourceStop})',
    BlockquoteBlock() =>
      'BlockquoteBlock('
          'children=[${block.children.map(_describeInline).join(', ')}], '
          'source=${block.sourceStart}..${block.sourceStop})',
    UnorderedListItemBlock() =>
      'UnorderedListItem(marker="${block.marker}", '
          'isTask=${block.isTask}, '
          'children=[${block.children.map(_describeInline).join(', ')}], '
          'source=${block.sourceStart}..${block.sourceStop})',
    OrderedListItemBlock() =>
      'OrderedListItem(number=${block.number}, '
          'punct="${block.punctuation}", '
          'isTask=${block.isTask}, '
          'children=[${block.children.map(_describeInline).join(', ')}], '
          'source=${block.sourceStart}..${block.sourceStop})',
  };
}

String _describeInline(MarkdownInline inline) {
  return switch (inline) {
    PlainTextInline() => 'Plain("${_escape(inline.text)}")',
    BoldInline() =>
      'Bold(${inline.delimiter}, '
          '[${inline.children.map(_describeInline).join(', ')}])',
    ItalicInline() =>
      'Italic(${inline.delimiter}, '
          '[${inline.children.map(_describeInline).join(', ')}])',
    BoldItalicInline() =>
      'BoldItalic([${inline.children.map(_describeInline).join(', ')}])',
    InlineCodeInline() => 'Code("${_escape(inline.code)}")',
    StrikethroughInline() =>
      'Strike([${inline.children.map(_describeInline).join(', ')}])',
    EscapedCharInline() => 'Escaped("${inline.character}")',
    LinkInline() =>
      'Link("${_escape(inline.text)}", "${_escape(inline.url)}"'
          '${inline.title != null ? ', "${_escape(inline.title!)}"' : ''})',
    ImageInline() =>
      'Image("${_escape(inline.alt)}", "${_escape(inline.url)}"'
          '${inline.title != null ? ', "${_escape(inline.title!)}"' : ''})',
    AutolinkInline() => 'Autolink("${_escape(inline.url)}")',
  };
}

String _escape(String s) => s.replaceAll('\n', '\\n').replaceAll('"', '\\"');
