import '../core/markdown_nodes.dart';
import 'emoji_map.dart';

/// Converts a [MarkdownDocument] AST to HTML string.
class MarkdownToHtmlConverter {
  /// Convert a parsed markdown document to HTML.
  String convert(MarkdownDocument document) {
    // Collect headings for TOC generation.
    _headings = <(int level, String text)>[];
    for (final block in document.blocks) {
      if (block is HeadingBlock) {
        final text = block.children.map(_inlineToPlainText).join();
        _headings.add((block.level, text));
      } else if (block is SetextHeadingBlock) {
        final text = block.children.map(_inlineToPlainText).join();
        _headings.add((block.level, text));
      }
    }

    final buffer = StringBuffer();
    final blocks = document.blocks;
    var i = 0;
    while (i < blocks.length) {
      final block = blocks[i];

      // Group consecutive list items into <ul> or <ol>.
      if (block is UnorderedListItemBlock) {
        buffer.write('<ul>\n');
        while (i < blocks.length && blocks[i] is UnorderedListItemBlock) {
          buffer.write(_convertListItem(blocks[i] as UnorderedListItemBlock));
          i++;
        }
        buffer.write('</ul>\n');
        continue;
      }

      if (block is OrderedListItemBlock) {
        final startNum = (block).number;
        if (startNum != 1) {
          buffer.write('<ol start="$startNum">\n');
        } else {
          buffer.write('<ol>\n');
        }
        while (i < blocks.length && blocks[i] is OrderedListItemBlock) {
          buffer.write(_convertOrderedListItem(blocks[i] as OrderedListItemBlock));
          i++;
        }
        buffer.write('</ol>\n');
        continue;
      }

      buffer.write(_convertBlock(block));
      i++;
    }

    return buffer.toString();
  }

  String _convertBlock(MarkdownBlock block) {
    switch (block) {
      case HeadingBlock():
        final content = _convertInlines(block.children);
        return '<h${block.level}>$content</h${block.level}>\n';

      case SetextHeadingBlock():
        final content = _convertInlines(block.children);
        return '<h${block.level}>$content</h${block.level}>\n';

      case ParagraphBlock():
        final content = _convertInlines(block.children);
        return '<p>$content</p>\n';

      case ThematicBreakBlock():
        return '<hr>\n';

      case BlankLineBlock():
        return '';

      case FencedCodeBlock():
        final escaped = _escapeHtml(block.code);
        // Remove trailing newline from code content for cleaner output.
        final trimmed = escaped.endsWith('\n')
            ? escaped.substring(0, escaped.length - 1)
            : escaped;
        if (block.language != null && block.language!.isNotEmpty) {
          return '<pre><code class="language-${block.language}">$trimmed</code></pre>\n';
        }
        return '<pre><code>$trimmed</code></pre>\n';

      case BlockquoteBlock():
        final content = _convertInlines(block.children);
        return '<blockquote><p>$content</p></blockquote>\n';

      case TableBlock():
        return _convertTable(block);

      // List items handled by grouping in convert().
      case UnorderedListItemBlock():
        return _convertListItem(block);

      case OrderedListItemBlock():
        return _convertOrderedListItem(block);

      case MathBlock():
        return '<pre class="math">\$\$\n${_escapeHtml(block.expression)}\n\$\$</pre>\n';

      case FootnoteDefinitionBlock():
        final content = _convertInlines(block.children);
        return '<div class="footnote" data-label="${_escapeHtml(block.label)}"><p>$content</p></div>\n';

      case YamlFrontMatterBlock():
        return '<!-- front matter -->\n';

      case TableOfContentsBlock():
        return _buildTocHtml();
    }
  }

  String _convertListItem(UnorderedListItemBlock block) {
    final content = _convertInlines(block.children);
    if (block.isTask) {
      final checkbox = block.taskChecked == true
          ? '<input type="checkbox" checked disabled> '
          : '<input type="checkbox" disabled> ';
      return '<li>$checkbox$content</li>\n';
    }
    return '<li>$content</li>\n';
  }

  String _convertOrderedListItem(OrderedListItemBlock block) {
    final content = _convertInlines(block.children);
    if (block.isTask) {
      final checkbox = block.taskChecked == true
          ? '<input type="checkbox" checked disabled> '
          : '<input type="checkbox" disabled> ';
      return '<li>$checkbox$content</li>\n';
    }
    return '<li>$content</li>\n';
  }

  String _convertTable(TableBlock block) {
    final buf = StringBuffer();
    buf.write('<table>\n<thead>\n<tr>\n');
    for (var i = 0; i < block.headerRow.cells.length; i++) {
      final align = i < block.alignments.length ? block.alignments[i] : TableAlignment.none;
      final alignAttr = _alignAttr(align);
      buf.write('<th$alignAttr>${_escapeHtml(block.headerRow.cells[i].text.trim())}</th>\n');
    }
    buf.write('</tr>\n</thead>\n');

    if (block.bodyRows.isNotEmpty) {
      buf.write('<tbody>\n');
      for (final row in block.bodyRows) {
        buf.write('<tr>\n');
        for (var i = 0; i < row.cells.length; i++) {
          final align = i < block.alignments.length ? block.alignments[i] : TableAlignment.none;
          final alignAttr = _alignAttr(align);
          buf.write('<td$alignAttr>${_escapeHtml(row.cells[i].text.trim())}</td>\n');
        }
        buf.write('</tr>\n');
      }
      buf.write('</tbody>\n');
    }

    buf.write('</table>\n');
    return buf.toString();
  }

  String _alignAttr(TableAlignment align) {
    return switch (align) {
      TableAlignment.left => ' align="left"',
      TableAlignment.center => ' align="center"',
      TableAlignment.right => ' align="right"',
      TableAlignment.none => '',
    };
  }

  String _convertInlines(List<MarkdownInline> inlines) {
    return inlines.map(_convertInline).join();
  }

  String _convertInline(MarkdownInline inline) {
    switch (inline) {
      case PlainTextInline():
        return _escapeHtml(inline.text);

      case BoldInline():
        return '<strong>${_convertInlines(inline.children)}</strong>';

      case ItalicInline():
        return '<em>${_convertInlines(inline.children)}</em>';

      case BoldItalicInline():
        return '<strong><em>${_convertInlines(inline.children)}</em></strong>';

      case InlineCodeInline():
        return '<code>${_escapeHtml(inline.code)}</code>';

      case StrikethroughInline():
        return '<del>${_convertInlines(inline.children)}</del>';

      case HighlightInline():
        return '<mark>${_convertInlines(inline.children)}</mark>';

      case SubscriptInline():
        return '<sub>${_convertInlines(inline.children)}</sub>';

      case SuperscriptInline():
        return '<sup>${_convertInlines(inline.children)}</sup>';

      case LinkInline():
        final titleAttr = inline.title != null ? ' title="${_escapeHtml(inline.title!)}"' : '';
        return '<a href="${_escapeHtml(inline.url)}"$titleAttr>${_escapeHtml(inline.text)}</a>';

      case ImageInline():
        final titleAttr = inline.title != null ? ' title="${_escapeHtml(inline.title!)}"' : '';
        return '<img src="${_escapeHtml(inline.url)}" alt="${_escapeHtml(inline.alt)}"$titleAttr>';

      case AutolinkInline():
        return '<a href="${_escapeHtml(inline.url)}">${_escapeHtml(inline.url)}</a>';

      case EscapedCharInline():
        return _escapeHtml(inline.character);

      case InlineMathInline():
        return '<code class="math">\$${_escapeHtml(inline.expression)}\$</code>';

      case FootnoteRefInline():
        return '<sup class="footnote-ref">[${_escapeHtml(inline.label)}]</sup>';

      case EmojiInline():
        final unicode = emojiShortcodes[inline.shortcode];
        return unicode ?? ':${_escapeHtml(inline.shortcode)}:';
    }
  }

  late List<(int level, String text)> _headings;

  String _buildTocHtml() {
    if (_headings.isEmpty) return '<nav class="toc"></nav>\n';
    final buf = StringBuffer('<nav class="toc"><ul>\n');
    for (final (level, text) in _headings) {
      final id = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      buf.write('<li class="toc-h$level"><a href="#$id">$text</a></li>\n');
    }
    buf.write('</ul></nav>\n');
    return buf.toString();
  }

  String _inlineToPlainText(MarkdownInline inline) {
    switch (inline) {
      case PlainTextInline():
        return inline.text;
      case BoldInline():
        return inline.children.map(_inlineToPlainText).join();
      case ItalicInline():
        return inline.children.map(_inlineToPlainText).join();
      case BoldItalicInline():
        return inline.children.map(_inlineToPlainText).join();
      case StrikethroughInline():
        return inline.children.map(_inlineToPlainText).join();
      case HighlightInline():
        return inline.children.map(_inlineToPlainText).join();
      case SubscriptInline():
        return inline.children.map(_inlineToPlainText).join();
      case SuperscriptInline():
        return inline.children.map(_inlineToPlainText).join();
      case InlineCodeInline():
        return inline.code;
      case LinkInline():
        return inline.text;
      case ImageInline():
        return inline.alt;
      case AutolinkInline():
        return inline.url;
      case EscapedCharInline():
        return inline.character;
      case InlineMathInline():
        return inline.expression;
      case FootnoteRefInline():
        return '[^${inline.label}]';
      case EmojiInline():
        return ':${inline.shortcode}:';
    }
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
