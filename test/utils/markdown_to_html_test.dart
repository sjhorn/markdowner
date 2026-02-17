import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/utils/markdown_to_html.dart';

void main() {
  late MarkdownToHtmlConverter converter;

  setUp(() {
    converter = MarkdownToHtmlConverter();
  });

  /// Helper: parse markdown, convert to HTML.
  String toHtml(String markdown) {
    final controller = MarkdownEditingController(text: markdown);
    final html = converter.convert(controller.document);
    controller.dispose();
    return html;
  }

  group('MarkdownToHtmlConverter', () {
    group('headings', () {
      test('converts H1', () {
        expect(toHtml('# Hello\n'), '<h1>Hello</h1>\n');
      });

      test('converts H3', () {
        expect(toHtml('### Hello\n'), '<h3>Hello</h3>\n');
      });

      test('converts H6', () {
        expect(toHtml('###### Hello\n'), '<h6>Hello</h6>\n');
      });

      test('converts heading with inline formatting', () {
        expect(toHtml('# **Bold** heading\n'),
            '<h1><strong>Bold</strong> heading</h1>\n');
      });
    });

    group('paragraphs', () {
      test('converts plain paragraph', () {
        expect(toHtml('Hello world\n'), '<p>Hello world</p>\n');
      });

      test('converts paragraph with bold', () {
        expect(toHtml('Hello **world**\n'),
            '<p>Hello <strong>world</strong></p>\n');
      });

      test('converts paragraph with italic', () {
        expect(toHtml('Hello *world*\n'),
            '<p>Hello <em>world</em></p>\n');
      });

      test('converts paragraph with inline code', () {
        expect(toHtml('Hello `code`\n'),
            '<p>Hello <code>code</code></p>\n');
      });

      test('converts paragraph with strikethrough', () {
        expect(toHtml('Hello ~~deleted~~\n'),
            '<p>Hello <del>deleted</del></p>\n');
      });

      test('converts paragraph with link', () {
        expect(toHtml('[Flutter](https://flutter.dev)\n'),
            '<p><a href="https://flutter.dev">Flutter</a></p>\n');
      });

      test('converts paragraph with image', () {
        expect(toHtml('![alt](http://img.png)\n'),
            '<p><img src="http://img.png" alt="alt"></p>\n');
      });
    });

    group('thematic break', () {
      test('converts ---', () {
        expect(toHtml('---\n'), '<hr>\n');
      });

      test('converts ***', () {
        expect(toHtml('***\n'), '<hr>\n');
      });
    });

    group('code blocks', () {
      test('converts fenced code block without language', () {
        expect(toHtml('```\ncode\n```\n'),
            '<pre><code>code</code></pre>\n');
      });

      test('converts fenced code block with language', () {
        expect(toHtml('```dart\nvoid main() {}\n```\n'),
            '<pre><code class="language-dart">void main() {}</code></pre>\n');
      });

      test('escapes HTML in code blocks', () {
        expect(toHtml('```\n<div>&</div>\n```\n'),
            '<pre><code>&lt;div&gt;&amp;&lt;/div&gt;</code></pre>\n');
      });
    });

    group('blockquotes', () {
      test('converts blockquote', () {
        expect(toHtml('> Hello\n'),
            '<blockquote><p>Hello</p></blockquote>\n');
      });

      test('converts blockquote with bold', () {
        expect(toHtml('> **bold** text\n'),
            '<blockquote><p><strong>bold</strong> text</p></blockquote>\n');
      });
    });

    group('lists', () {
      test('converts unordered list', () {
        final html = toHtml('- first\n- second\n- third\n');
        expect(html, contains('<ul>'));
        expect(html, contains('<li>first</li>'));
        expect(html, contains('<li>second</li>'));
        expect(html, contains('<li>third</li>'));
        expect(html, contains('</ul>'));
      });

      test('converts ordered list', () {
        final html = toHtml('1. first\n2. second\n3. third\n');
        expect(html, contains('<ol>'));
        expect(html, contains('<li>first</li>'));
        expect(html, contains('<li>second</li>'));
        expect(html, contains('<li>third</li>'));
        expect(html, contains('</ol>'));
      });

      test('converts task list with unchecked item', () {
        final html = toHtml('- [ ] task\n');
        expect(html, contains('<input type="checkbox" disabled>'));
        expect(html, contains('task'));
      });

      test('converts task list with checked item', () {
        final html = toHtml('- [x] done\n');
        expect(html, contains('<input type="checkbox" checked disabled>'));
        expect(html, contains('done'));
      });
    });

    group('blank lines', () {
      test('blank lines produce no output', () {
        expect(toHtml('\n'), '');
      });
    });

    group('autolinks', () {
      test('converts autolink', () {
        expect(toHtml('<https://dart.dev>\n'),
            '<p><a href="https://dart.dev">https://dart.dev</a></p>\n');
      });
    });

    group('escaped characters', () {
      test('converts escaped character', () {
        expect(toHtml('\\*not italic\\*\n'),
            '<p>*not italic*</p>\n');
      });
    });

    group('multi-block document', () {
      test('converts full document', () {
        final md = '''# Title

Hello **world**.

- item 1
- item 2

---

> Quote
''';
        final html = toHtml(md);
        expect(html, contains('<h1>Title</h1>'));
        expect(html, contains('<p>Hello <strong>world</strong>.</p>'));
        expect(html, contains('<ul>'));
        expect(html, contains('<li>item 1</li>'));
        expect(html, contains('<li>item 2</li>'));
        expect(html, contains('</ul>'));
        expect(html, contains('<hr>'));
        expect(html, contains('<blockquote>'));
      });
    });

    group('HTML escaping', () {
      test('escapes ampersands', () {
        expect(toHtml('A & B\n'), '<p>A &amp; B</p>\n');
      });

      test('escapes angle brackets', () {
        expect(toHtml('a < b > c\n'), '<p>a &lt; b &gt; c</p>\n');
      });
    });
  });

  group('extensions', () {
    test('highlight → <mark>', () {
      expect(toHtml('==highlighted==\n'), '<p><mark>highlighted</mark></p>\n');
    });

    test('subscript → <sub>', () {
      expect(toHtml('~sub~\n'), '<p><sub>sub</sub></p>\n');
    });

    test('superscript → <sup>', () {
      expect(toHtml('^sup^\n'), '<p><sup>sup</sup></p>\n');
    });

    test('mixed extensions', () {
      expect(
        toHtml('H~2~O and x^2^\n'),
        '<p>H<sub>2</sub>O and x<sup>2</sup></p>\n',
      );
    });
  });
}
