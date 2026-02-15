import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Converts an HTML string to Markdown.
class HtmlToMarkdownConverter {
  /// Convert an HTML string to Markdown.
  String convert(String html) {
    final document = html_parser.parse(html);
    final buffer = StringBuffer();
    _convertNodes(document.body?.nodes ?? [], buffer);
    return buffer.toString().trimRight();
    // trimRight to clean up trailing whitespace, then add final newline.
  }

  void _convertNodes(List<dom.Node> nodes, StringBuffer buffer) {
    for (final node in nodes) {
      _convertNode(node, buffer);
    }
  }

  void _convertNode(dom.Node node, StringBuffer buffer) {
    if (node is dom.Text) {
      // Collapse whitespace for inline text.
      final text = node.text;
      buffer.write(text);
      return;
    }

    if (node is dom.Element) {
      _convertElement(node, buffer);
      return;
    }
  }

  void _convertElement(dom.Element element, StringBuffer buffer) {
    final tag = element.localName?.toLowerCase() ?? '';

    switch (tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = int.parse(tag.substring(1));
        buffer.write('${'#' * level} ');
        _convertInlineChildren(element.nodes, buffer);
        buffer.write('\n');

      case 'p':
        _convertInlineChildren(element.nodes, buffer);
        buffer.write('\n\n');

      case 'br':
        buffer.write('\n');

      case 'strong' || 'b':
        buffer.write('**');
        _convertInlineChildren(element.nodes, buffer);
        buffer.write('**');

      case 'em' || 'i':
        buffer.write('*');
        _convertInlineChildren(element.nodes, buffer);
        buffer.write('*');

      case 'del' || 's' || 'strike':
        buffer.write('~~');
        _convertInlineChildren(element.nodes, buffer);
        buffer.write('~~');

      case 'code':
        // Check if inside a <pre> — handled by parent <pre> case.
        if (element.parent?.localName == 'pre') {
          // Code block content.
          buffer.write(element.text);
        } else {
          buffer.write('`');
          buffer.write(element.text);
          buffer.write('`');
        }

      case 'pre':
        // Look for <code> child.
        final codeChild = element.children
            .where((e) => e.localName == 'code')
            .firstOrNull;
        if (codeChild != null) {
          final lang = _extractLanguage(codeChild);
          buffer.write('```$lang\n');
          buffer.write(codeChild.text);
          buffer.write('\n```\n\n');
        } else {
          buffer.write('```\n');
          buffer.write(element.text);
          buffer.write('\n```\n\n');
        }

      case 'a':
        final href = element.attributes['href'] ?? '';
        final text = element.text;
        buffer.write('[$text]($href)');

      case 'img':
        final src = element.attributes['src'] ?? '';
        final alt = element.attributes['alt'] ?? '';
        buffer.write('![$alt]($src)');

      case 'ul':
        _convertListItems(element, ordered: false, buffer: buffer);

      case 'ol':
        _convertListItems(element, ordered: true, buffer: buffer);

      case 'li':
        // Should be handled by parent <ul>/<ol>.
        _convertInlineChildren(element.nodes, buffer);

      case 'blockquote':
        final innerBuf = StringBuffer();
        _convertNodes(element.nodes, innerBuf);
        final lines = innerBuf.toString().trimRight().split('\n');
        for (final line in lines) {
          buffer.write('> $line\n');
        }
        buffer.write('\n');

      case 'hr':
        buffer.write('---\n\n');

      case 'table':
        _convertTable(element, buffer);

      case 'div' || 'section' || 'article' || 'main' || 'header' || 'footer' || 'nav':
        // Block containers: recurse into children.
        _convertNodes(element.nodes, buffer);

      case 'span':
        // Inline container: recurse into children.
        _convertInlineChildren(element.nodes, buffer);

      case 'input':
        // Task list checkbox.
        final isCheckbox = element.attributes['type'] == 'checkbox';
        if (isCheckbox) {
          final checked = element.attributes.containsKey('checked');
          buffer.write(checked ? '[x] ' : '[ ] ');
        }

      default:
        // Unknown element: output its text content.
        _convertInlineChildren(element.nodes, buffer);
    }
  }

  void _convertInlineChildren(List<dom.Node> nodes, StringBuffer buffer) {
    for (final node in nodes) {
      _convertNode(node, buffer);
    }
  }

  void _convertListItems(
    dom.Element listElement, {
    required bool ordered,
    required StringBuffer buffer,
  }) {
    var index = 1;
    // Try to read start attribute for ordered lists.
    if (ordered) {
      final startAttr = listElement.attributes['start'];
      if (startAttr != null) {
        index = int.tryParse(startAttr) ?? 1;
      }
    }

    for (final child in listElement.children) {
      if (child.localName != 'li') continue;

      final prefix = ordered ? '$index. ' : '- ';
      buffer.write(prefix);

      // Convert li contents inline.
      final innerBuf = StringBuffer();
      _convertInlineChildren(child.nodes, innerBuf);
      // Collapse multiple consecutive spaces (e.g., from checkbox + text node).
      final content = innerBuf.toString().trimRight().replaceAll(RegExp(r'  +'), ' ');
      buffer.write(content);
      buffer.write('\n');

      index++;
    }
    buffer.write('\n');
  }

  void _convertTable(dom.Element table, StringBuffer buffer) {
    final rows = <List<String>>[];
    final alignments = <String>[];

    // Extract header.
    final thead = table.querySelector('thead');
    final headerRow = thead?.querySelector('tr') ?? table.querySelector('tr');
    if (headerRow != null) {
      final cells = <String>[];
      for (final th in headerRow.children) {
        cells.add(th.text.trim());
        final align = th.attributes['align'] ?? '';
        alignments.add(align);
      }
      rows.add(cells);
    }

    // Extract body rows.
    final tbody = table.querySelector('tbody');
    final bodyRows = tbody?.querySelectorAll('tr') ??
        table.querySelectorAll('tr').skip(1);
    for (final tr in bodyRows) {
      final cells = <String>[];
      for (final td in tr.children) {
        cells.add(td.text.trim());
      }
      rows.add(cells);
    }

    if (rows.isEmpty) return;

    // Determine column count.
    final colCount = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);

    // Write header row.
    final header = rows[0];
    buffer.write('| ');
    for (var i = 0; i < colCount; i++) {
      buffer.write(i < header.length ? header[i] : '');
      if (i < colCount - 1) buffer.write(' | ');
    }
    buffer.write(' |\n');

    // Write delimiter row.
    buffer.write('| ');
    for (var i = 0; i < colCount; i++) {
      final align = i < alignments.length ? alignments[i] : '';
      if (align == 'center') {
        buffer.write(':---:');
      } else if (align == 'right') {
        buffer.write('---:');
      } else if (align == 'left') {
        buffer.write(':---');
      } else {
        buffer.write('---');
      }
      if (i < colCount - 1) buffer.write(' | ');
    }
    buffer.write(' |\n');

    // Write body rows.
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      buffer.write('| ');
      for (var i = 0; i < colCount; i++) {
        buffer.write(i < row.length ? row[i] : '');
        if (i < colCount - 1) buffer.write(' | ');
      }
      buffer.write(' |\n');
    }
    buffer.write('\n');
  }

  String _extractLanguage(dom.Element codeElement) {
    // Look for "language-xxx" class.
    final classes = codeElement.className.split(' ');
    for (final cls in classes) {
      if (cls.startsWith('language-')) {
        return cls.substring('language-'.length);
      }
    }
    return '';
  }
}
