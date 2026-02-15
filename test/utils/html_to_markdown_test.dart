import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/utils/html_to_markdown.dart';

void main() {
  late HtmlToMarkdownConverter converter;

  setUp(() {
    converter = HtmlToMarkdownConverter();
  });

  /// Helper: convert HTML to Markdown.
  String toMd(String html) => converter.convert(html);

  group('HtmlToMarkdownConverter', () {
    group('headings', () {
      test('converts h1', () {
        expect(toMd('<h1>Hello</h1>'), '# Hello');
      });

      test('converts h3', () {
        expect(toMd('<h3>Hello</h3>'), '### Hello');
      });

      test('converts h6', () {
        expect(toMd('<h6>Hello</h6>'), '###### Hello');
      });
    });

    group('paragraphs', () {
      test('converts paragraph', () {
        expect(toMd('<p>Hello world</p>'), 'Hello world');
      });

      test('converts multiple paragraphs', () {
        expect(toMd('<p>First</p><p>Second</p>'), 'First\n\nSecond');
      });
    });

    group('inline formatting', () {
      test('converts strong/bold', () {
        expect(toMd('<p>Hello <strong>world</strong></p>'),
            'Hello **world**');
      });

      test('converts b tag', () {
        expect(toMd('<p>Hello <b>world</b></p>'),
            'Hello **world**');
      });

      test('converts em/italic', () {
        expect(toMd('<p>Hello <em>world</em></p>'),
            'Hello *world*');
      });

      test('converts i tag', () {
        expect(toMd('<p>Hello <i>world</i></p>'),
            'Hello *world*');
      });

      test('converts inline code', () {
        expect(toMd('<p>Hello <code>code</code></p>'),
            'Hello `code`');
      });

      test('converts strikethrough (del)', () {
        expect(toMd('<p>Hello <del>deleted</del></p>'),
            'Hello ~~deleted~~');
      });

      test('converts strikethrough (s)', () {
        expect(toMd('<p>Hello <s>deleted</s></p>'),
            'Hello ~~deleted~~');
      });
    });

    group('links and images', () {
      test('converts link', () {
        expect(toMd('<a href="https://flutter.dev">Flutter</a>'),
            '[Flutter](https://flutter.dev)');
      });

      test('converts image', () {
        expect(toMd('<img src="http://img.png" alt="Dash">'),
            '![Dash](http://img.png)');
      });
    });

    group('code blocks', () {
      test('converts pre/code without language', () {
        expect(toMd('<pre><code>hello()</code></pre>'),
            '```\nhello()\n```');
      });

      test('converts pre/code with language class', () {
        expect(toMd('<pre><code class="language-dart">void main() {}</code></pre>'),
            '```dart\nvoid main() {}\n```');
      });
    });

    group('lists', () {
      test('converts unordered list', () {
        final md = toMd('<ul><li>first</li><li>second</li></ul>');
        expect(md, contains('- first'));
        expect(md, contains('- second'));
      });

      test('converts ordered list', () {
        final md = toMd('<ol><li>first</li><li>second</li></ol>');
        expect(md, contains('1. first'));
        expect(md, contains('2. second'));
      });

      test('converts ordered list with start attribute', () {
        final md = toMd('<ol start="5"><li>fifth</li><li>sixth</li></ol>');
        expect(md, contains('5. fifth'));
        expect(md, contains('6. sixth'));
      });
    });

    group('blockquotes', () {
      test('converts blockquote', () {
        expect(toMd('<blockquote><p>quoted</p></blockquote>'),
            contains('> quoted'));
      });
    });

    group('horizontal rule', () {
      test('converts hr', () {
        expect(toMd('<hr>'), contains('---'));
      });
    });

    group('line breaks', () {
      test('converts br', () {
        expect(toMd('<p>line1<br>line2</p>'), 'line1\nline2');
      });
    });

    group('tables', () {
      test('converts simple table', () {
        final html = '''
<table>
  <thead><tr><th>A</th><th>B</th></tr></thead>
  <tbody><tr><td>1</td><td>2</td></tr></tbody>
</table>''';
        final md = toMd(html);
        expect(md, contains('| A | B |'));
        expect(md, contains('| --- | --- |'));
        expect(md, contains('| 1 | 2 |'));
      });
    });

    group('nested formatting', () {
      test('converts nested bold inside italic', () {
        expect(toMd('<p><em><strong>text</strong></em></p>'),
            '***text***');
      });

      test('converts bold inside paragraph', () {
        expect(toMd('<p>say <strong>Hello</strong> world</p>'),
            'say **Hello** world');
      });
    });

    group('unknown tags', () {
      test('passes through text from unknown tags', () {
        expect(toMd('<p><unknown>text</unknown></p>'),
            'text');
      });

      test('handles div containers', () {
        expect(toMd('<div><p>hello</p></div>'),
            'hello');
      });
    });

    group('task list', () {
      test('converts task list with checkbox', () {
        final html = '<ul><li><input type="checkbox"> task</li></ul>';
        final md = toMd(html);
        expect(md, contains('- [ ] task'));
      });

      test('converts checked task list', () {
        final html = '<ul><li><input type="checkbox" checked> done</li></ul>';
        final md = toMd(html);
        expect(md, contains('- [x] done'));
      });
    });

    group('empty and edge cases', () {
      test('handles empty string', () {
        expect(toMd(''), isEmpty);
      });

      test('handles plain text without tags', () {
        expect(toMd('Just text'), 'Just text');
      });
    });
  });
}
