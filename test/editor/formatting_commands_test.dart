import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';

void main() {
  late MarkdownEditingController controller;

  setUp(() {
    controller = MarkdownEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('toggleBold', () {
    test('wraps selected text with **', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      controller.toggleBold();

      expect(controller.text, '**Hello**\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 7));
    });

    test('unwraps already bold text', () {
      controller.text = '**Hello**\n';
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 7);

      controller.toggleBold();

      expect(controller.text, 'Hello\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5));
    });

    test('inserts empty bold markers at collapsed cursor', () {
      controller.text = 'Hello\n';
      controller.selection =
          const TextSelection.collapsed(offset: 5);

      controller.toggleBold();

      expect(controller.text, 'Hello****\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 7));
    });

    test('works mid-line', () {
      controller.text = 'say Hello world\n';
      controller.selection = const TextSelection(baseOffset: 4, extentOffset: 9);

      controller.toggleBold();

      expect(controller.text, 'say **Hello** world\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 6, extentOffset: 11));
    });
  });

  group('toggleItalic', () {
    test('wraps selected text with *', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      controller.toggleItalic();

      expect(controller.text, '*Hello*\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 1, extentOffset: 6));
    });

    test('unwraps already italic text', () {
      controller.text = '*Hello*\n';
      controller.selection = const TextSelection(baseOffset: 1, extentOffset: 6);

      controller.toggleItalic();

      expect(controller.text, 'Hello\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5));
    });

    test('inserts empty italic markers at collapsed cursor', () {
      controller.text = 'Hello\n';
      controller.selection =
          const TextSelection.collapsed(offset: 5);

      controller.toggleItalic();

      expect(controller.text, 'Hello**\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 6));
    });

    test('works mid-line', () {
      controller.text = 'say Hello world\n';
      controller.selection = const TextSelection(baseOffset: 4, extentOffset: 9);

      controller.toggleItalic();

      expect(controller.text, 'say *Hello* world\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 5, extentOffset: 10));
    });
  });

  group('toggleInlineCode', () {
    test('wraps selected text with backtick', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      controller.toggleInlineCode();

      expect(controller.text, '`Hello`\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 1, extentOffset: 6));
    });

    test('unwraps already code text', () {
      controller.text = '`Hello`\n';
      controller.selection = const TextSelection(baseOffset: 1, extentOffset: 6);

      controller.toggleInlineCode();

      expect(controller.text, 'Hello\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5));
    });

    test('inserts empty code markers at collapsed cursor', () {
      controller.text = 'Hello\n';
      controller.selection =
          const TextSelection.collapsed(offset: 5);

      controller.toggleInlineCode();

      expect(controller.text, 'Hello``\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 6));
    });
  });

  group('toggleStrikethrough', () {
    test('wraps selected text with ~~', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      controller.toggleStrikethrough();

      expect(controller.text, '~~Hello~~\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 7));
    });

    test('unwraps already strikethrough text', () {
      controller.text = '~~Hello~~\n';
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 7);

      controller.toggleStrikethrough();

      expect(controller.text, 'Hello\n');
      expect(controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5));
    });

    test('inserts empty strikethrough markers at collapsed cursor', () {
      controller.text = 'Hello\n';
      controller.selection =
          const TextSelection.collapsed(offset: 5);

      controller.toggleStrikethrough();

      expect(controller.text, 'Hello~~~~\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 7));
    });
  });

  group('setHeadingLevel', () {
    test('sets heading level 1', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 3);

      controller.setHeadingLevel(1);

      expect(controller.text, '# Hello\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 5));
    });

    test('sets heading level 3', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 3);

      controller.setHeadingLevel(3);

      expect(controller.text, '### Hello\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 7));
    });

    test('replaces existing heading prefix', () {
      controller.text = '# Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 4);

      controller.setHeadingLevel(3);

      expect(controller.text, '### Hello\n');
      // cursor was at offset 4 in "# Hello", that's 2 chars into "Hello"
      // new prefix is "### " (4 chars), cursor should be at 4 + (4-2) = 6
      expect(controller.selection,
          const TextSelection.collapsed(offset: 6));
    });

    test('removes heading prefix with level 0', () {
      controller.text = '## Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      controller.setHeadingLevel(0);

      expect(controller.text, 'Hello\n');
      // cursor was at offset 5 in "## Hello", that's 2 chars into "Hello"
      // prefix removed (3 chars "## "), cursor should be at 5 - 3 = 2
      expect(controller.selection,
          const TextSelection.collapsed(offset: 2));
    });

    test('works on correct line in multi-line text', () {
      controller.text = 'Line one\nLine two\nLine three\n';
      // Cursor on "Line two" (offset 10 = start of "L" in "Line two")
      controller.selection = const TextSelection.collapsed(offset: 10);

      controller.setHeadingLevel(2);

      expect(controller.text, 'Line one\n## Line two\nLine three\n');
      // prefix "## " added (3 chars), cursor was at 10, now at 13
      expect(controller.selection,
          const TextSelection.collapsed(offset: 13));
    });

    test('setting same level removes the heading', () {
      controller.text = '## Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      controller.setHeadingLevel(2);

      expect(controller.text, 'Hello\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 2));
    });
  });

  group('indent', () {
    test('adds 2-space indent to unordered list item', () {
      controller.text = '- item\n';
      controller.selection = const TextSelection.collapsed(offset: 4);

      controller.indent();

      expect(controller.text, '  - item\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 6));
    });

    test('adds 2-space indent to ordered list item', () {
      controller.text = '1. item\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      controller.indent();

      expect(controller.text, '  1. item\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 7));
    });

    test('adds additional indent to already indented list item', () {
      controller.text = '  - item\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      controller.indent();

      expect(controller.text, '    - item\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 8));
    });

    test('inserts 2 spaces for non-list context', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 3);

      controller.indent();

      expect(controller.text, 'Hel  lo\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 5));
    });

    test('indents task list item', () {
      controller.text = '- [ ] task\n';
      controller.selection = const TextSelection.collapsed(offset: 8);

      controller.indent();

      expect(controller.text, '  - [ ] task\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 10));
    });

    test('works on correct line in multi-line text', () {
      controller.text = '- first\n- second\n- third\n';
      // cursor in "second" at offset 12
      controller.selection = const TextSelection.collapsed(offset: 12);

      controller.indent();

      expect(controller.text, '- first\n  - second\n- third\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 14));
    });
  });

  group('outdent', () {
    test('removes 2-space indent from list item', () {
      controller.text = '  - item\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      controller.outdent();

      expect(controller.text, '- item\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 4));
    });

    test('removes 2-space indent from ordered list item', () {
      controller.text = '  1. item\n';
      controller.selection = const TextSelection.collapsed(offset: 7);

      controller.outdent();

      expect(controller.text, '1. item\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 5));
    });

    test('does nothing if list item has no indent', () {
      controller.text = '- item\n';
      controller.selection = const TextSelection.collapsed(offset: 4);

      controller.outdent();

      expect(controller.text, '- item\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 4));
    });

    test('removes only 2 spaces from deeper indent', () {
      controller.text = '    - item\n';
      controller.selection = const TextSelection.collapsed(offset: 8);

      controller.outdent();

      expect(controller.text, '  - item\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 6));
    });

    test('does nothing for non-list context', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 3);

      controller.outdent();

      expect(controller.text, 'Hello\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 3));
    });

    test('outdents task list item', () {
      controller.text = '  - [ ] task\n';
      controller.selection = const TextSelection.collapsed(offset: 10);

      controller.outdent();

      expect(controller.text, '- [ ] task\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 8));
    });
  });

  group('insertLink', () {
    test('inserts empty link template at collapsed cursor', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      controller.insertLink();

      expect(controller.text, 'Hello[](url)\n');
      // cursor should be inside the []
      expect(controller.selection,
          const TextSelection.collapsed(offset: 6));
    });

    test('wraps selection as link text', () {
      controller.text = 'click here please\n';
      controller.selection =
          const TextSelection(baseOffset: 6, extentOffset: 10);

      controller.insertLink();

      expect(controller.text, 'click [here](url) please\n');
      // cursor should be inside the () selecting "url"
      expect(controller.selection,
          const TextSelection(baseOffset: 13, extentOffset: 16));
    });
  });

  group('toggleCodeBlock', () {
    test('wraps current line in code fences at collapsed cursor', () {
      controller.text = 'some code\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      controller.toggleCodeBlock();

      expect(controller.text, '```\nsome code\n```\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 9));
    });

    test('unwraps code fences if already inside', () {
      controller.text = '```\nsome code\n```\n';
      controller.selection = const TextSelection.collapsed(offset: 8);

      controller.toggleCodeBlock();

      expect(controller.text, 'some code\n');
      // offset 8 was ' ' between "some" and "code"; removing "```\n" (4 chars)
      expect(controller.selection,
          const TextSelection.collapsed(offset: 4));
    });

    test('wraps multi-line selection in code fences', () {
      controller.text = 'line one\nline two\n';
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 17);

      controller.toggleCodeBlock();

      expect(controller.text, '```\nline one\nline two\n```\n');
    });

    test('wraps line in code fences with blank lines preserved', () {
      controller.text = 'before\nsome code\nafter\n';
      controller.selection = const TextSelection.collapsed(offset: 12);

      controller.toggleCodeBlock();

      expect(controller.text, 'before\n```\nsome code\n```\nafter\n');
    });
  });

  group('toggleHighlight', () {
    test('wraps selected text with ==', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      controller.toggleHighlight();

      expect(controller.text, '==Hello==\n');
      expect(controller.selection.baseOffset, 2);
      expect(controller.selection.extentOffset, 7);
    });

    test('unwraps ==text==', () {
      controller.text = '==Hello==\n';
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 7);

      controller.toggleHighlight();

      expect(controller.text, 'Hello\n');
      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, 5);
    });

    test('collapsed cursor inserts ==== with cursor between', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      controller.toggleHighlight();

      expect(controller.text, 'Hello====\n');
      expect(controller.selection.baseOffset, 7);
    });
  });

  group('toggleSubscript', () {
    test('wraps selected text with ~', () {
      controller.text = 'H2O\n';
      controller.selection = const TextSelection(baseOffset: 1, extentOffset: 2);

      controller.toggleSubscript();

      expect(controller.text, 'H~2~O\n');
      expect(controller.selection.baseOffset, 2);
      expect(controller.selection.extentOffset, 3);
    });

    test('unwraps ~text~', () {
      controller.text = 'H~2~O\n';
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 3);

      controller.toggleSubscript();

      expect(controller.text, 'H2O\n');
      expect(controller.selection.baseOffset, 1);
      expect(controller.selection.extentOffset, 2);
    });

    test('collapsed cursor inserts ~~ with cursor between', () {
      controller.text = 'text\n';
      controller.selection = const TextSelection.collapsed(offset: 4);

      controller.toggleSubscript();

      expect(controller.text, 'text~~\n');
      expect(controller.selection.baseOffset, 5);
    });

    test('does not unwrap ~~ strikethrough delimiters', () {
      // Selection inside ~~text~~ should not be unwrapped by subscript toggle
      controller.text = '~~text~~\n';
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 6);

      controller.toggleSubscript();

      // Should wrap with additional ~ (not unwrap the ~~)
      // The ~ before selection is part of ~~ (double), so unwrap is blocked.
      expect(controller.text, '~~~text~~~\n');
    });
  });

  group('toggleSuperscript', () {
    test('wraps selected text with ^', () {
      controller.text = 'x2\n';
      controller.selection = const TextSelection(baseOffset: 1, extentOffset: 2);

      controller.toggleSuperscript();

      expect(controller.text, 'x^2^\n');
      expect(controller.selection.baseOffset, 2);
      expect(controller.selection.extentOffset, 3);
    });

    test('unwraps ^text^', () {
      controller.text = 'x^2^\n';
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 3);

      controller.toggleSuperscript();

      expect(controller.text, 'x2\n');
      expect(controller.selection.baseOffset, 1);
      expect(controller.selection.extentOffset, 2);
    });

    test('collapsed cursor inserts ^^ with cursor between', () {
      controller.text = 'x\n';
      controller.selection = const TextSelection.collapsed(offset: 1);

      controller.toggleSuperscript();

      expect(controller.text, 'x^^\n');
      expect(controller.selection.baseOffset, 2);
    });
  });

  group('insertImage', () {
    test('inserts image template at collapsed cursor', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      controller.insertImage();

      expect(controller.text, 'Hello![](url)\n');
      // cursor should be inside the [] (after "![")
      expect(controller.selection,
          const TextSelection.collapsed(offset: 7));
    });

    test('wraps selection as image alt text', () {
      controller.text = 'a photo here\n';
      controller.selection =
          const TextSelection(baseOffset: 2, extentOffset: 7);

      controller.insertImage();

      expect(controller.text, 'a ![photo](url) here\n');
      // cursor should select "url" inside (): ![photo]( at position 11
      expect(controller.selection,
          const TextSelection(baseOffset: 11, extentOffset: 14));
    });

    test('inserts at start of text', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 0);

      controller.insertImage();

      expect(controller.text, '![](url)Hello\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 2));
    });

    test('inserts at end of text', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 6);

      controller.insertImage();

      expect(controller.text, 'Hello\n![](url)');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 8));
    });
  });

  group('insertImageMarkdown', () {
    test('inserts image with specific alt and url', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 5);

      controller.insertImageMarkdown('photo', 'https://x.com/img.png');

      expect(controller.text,
          'Hello![photo](https://x.com/img.png)\n');
      // cursor placed after closing )
      expect(controller.selection,
          const TextSelection.collapsed(offset: 36));
    });

    test('inserts at start of text', () {
      controller.text = 'Hello\n';
      controller.selection = const TextSelection.collapsed(offset: 0);

      controller.insertImageMarkdown('pic', 'http://example.com/a.jpg');

      expect(controller.text,
          '![pic](http://example.com/a.jpg)Hello\n');
      // ![pic](http://example.com/a.jpg) = 32 chars
      expect(controller.selection,
          const TextSelection.collapsed(offset: 32));
    });

    test('replaces selection with image markdown', () {
      controller.text = 'replace this text\n';
      controller.selection =
          const TextSelection(baseOffset: 8, extentOffset: 12);

      controller.insertImageMarkdown('alt', 'url');

      expect(controller.text, 'replace ![alt](url) text\n');
      expect(controller.selection,
          const TextSelection.collapsed(offset: 19));
    });
  });
}
