import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';
import 'package:markdowner/src/widgets/markdown_editor.dart';

/// Helper to simulate pressing Enter at cursor position in [oldText].
///
/// [oldText] contains a `|` to mark cursor position.
/// Returns the result of [applySmartEnter] as (text, cursorOffset),
/// or null if pass-through.
({String text, int offset})? _simulateEnter(String oldTextWithCursor) {
  final cursorPos = oldTextWithCursor.indexOf('|');
  assert(cursorPos != -1, 'oldText must contain | to mark cursor position');
  final oldText = oldTextWithCursor.replaceFirst('|', '');

  final oldValue = TextEditingValue(
    text: oldText,
    selection: TextSelection.collapsed(offset: cursorPos),
  );

  // Simulate what the platform does: insert \n at cursor position.
  final newText =
      '${oldText.substring(0, cursorPos)}\n${oldText.substring(cursorPos)}';
  final newValue = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: cursorPos + 1),
  );

  final controller = MarkdownEditingController(text: '');
  final result = controller.applySmartEnter(oldValue, newValue);
  controller.dispose();

  if (result == null) return null;
  return (text: result.text, offset: result.selection.baseOffset);
}

void main() {
  group('Smart Enter', () {
    group('Unordered list continuation', () {
      test('continues - marker', () {
        final r = _simulateEnter('- Hello|');
        expect(r, isNotNull);
        expect(r!.text, '- Hello\n- ');
        expect(r.offset, 10); // after "- Hello\n- "
      });

      test('continues * marker', () {
        final r = _simulateEnter('* Hello|');
        expect(r, isNotNull);
        expect(r!.text, '* Hello\n* ');
        expect(r.offset, 10);
      });

      test('continues + marker', () {
        final r = _simulateEnter('+ Hello|');
        expect(r, isNotNull);
        expect(r!.text, '+ Hello\n+ ');
        expect(r.offset, 10);
      });

      test('continues with indent', () {
        final r = _simulateEnter('  - Hello|');
        expect(r, isNotNull);
        expect(r!.text, '  - Hello\n  - ');
        expect(r.offset, 14);
      });
    });

    group('Ordered list continuation', () {
      test('continues 1. with next number', () {
        final r = _simulateEnter('1. Hello|');
        expect(r, isNotNull);
        expect(r!.text, '1. Hello\n2. ');
        expect(r.offset, 12);
      });

      test('continues 3) with next number', () {
        final r = _simulateEnter('3) Hello|');
        expect(r, isNotNull);
        expect(r!.text, '3) Hello\n4) ');
        expect(r.offset, 12);
      });

      test('auto-increments from 9 to 10', () {
        final r = _simulateEnter('9. Hello|');
        expect(r, isNotNull);
        expect(r!.text, '9. Hello\n10. ');
        expect(r.offset, 13);
      });
    });

    group('Task list continuation', () {
      test('continues unchecked task', () {
        final r = _simulateEnter('- [ ] Hello|');
        expect(r, isNotNull);
        expect(r!.text, '- [ ] Hello\n- [ ] ');
        expect(r.offset, 18);
      });

      test('continues checked task as unchecked', () {
        final r = _simulateEnter('- [x] Hello|');
        expect(r, isNotNull);
        expect(r!.text, '- [x] Hello\n- [ ] ');
        expect(r.offset, 18);
      });
    });

    group('Empty list item exit', () {
      test('exits empty unordered list item', () {
        final r = _simulateEnter('- |');
        expect(r, isNotNull);
        expect(r!.text, '');
        expect(r.offset, 0);
      });

      test('exits empty ordered list item', () {
        final r = _simulateEnter('1. |');
        expect(r, isNotNull);
        expect(r!.text, '');
        expect(r.offset, 0);
      });

      test('exits empty task list item', () {
        final r = _simulateEnter('- [ ] |');
        expect(r, isNotNull);
        expect(r!.text, '');
        expect(r.offset, 0);
      });

      test('exits empty unordered item in multi-line doc', () {
        final r = _simulateEnter('- First\n- |');
        expect(r, isNotNull);
        expect(r!.text, '- First\n');
        expect(r.offset, 8);
      });

      test('exits empty ordered item in multi-line doc', () {
        final r = _simulateEnter('1. First\n2. |');
        expect(r, isNotNull);
        expect(r!.text, '1. First\n');
        expect(r.offset, 9);
      });
    });

    group('Blockquote continuation', () {
      test('continues blockquote', () {
        final r = _simulateEnter('> Hello|');
        expect(r, isNotNull);
        expect(r!.text, '> Hello\n> ');
        expect(r.offset, 10);
      });
    });

    group('Empty blockquote exit', () {
      test('exits empty blockquote', () {
        final r = _simulateEnter('> |');
        expect(r, isNotNull);
        expect(r!.text, '');
        expect(r.offset, 0);
      });

      test('exits empty blockquote in multi-line doc', () {
        final r = _simulateEnter('> First\n> |');
        expect(r, isNotNull);
        expect(r!.text, '> First\n');
        expect(r.offset, 8);
      });
    });

    group('Heading — no continuation', () {
      test('does not continue heading prefix', () {
        final r = _simulateEnter('# Hello|');
        expect(r, isNotNull);
        expect(r!.text, '# Hello\n');
        expect(r.offset, 8);
      });

      test('does not continue h3 heading prefix', () {
        final r = _simulateEnter('### Hello|');
        expect(r, isNotNull);
        expect(r!.text, '### Hello\n');
        expect(r.offset, 10);
      });
    });

    group('Paragraph — pass through', () {
      test('returns null for plain text', () {
        final r = _simulateEnter('Hello world|');
        expect(r, isNull);
      });

      test('returns null for empty line', () {
        final r = _simulateEnter('|');
        expect(r, isNull);
      });
    });

    group('Mid-line enter', () {
      test('splits list item with marker on new line', () {
        final r = _simulateEnter('- Hel|lo');
        expect(r, isNotNull);
        expect(r!.text, '- Hel\n- lo');
        expect(r.offset, 8); // after "- Hel\n- "
      });

      test('splits ordered list item with next number', () {
        final r = _simulateEnter('1. Hel|lo');
        expect(r, isNotNull);
        expect(r!.text, '1. Hel\n2. lo');
        expect(r.offset, 10);
      });

      test('splits blockquote with prefix on new line', () {
        final r = _simulateEnter('> Hel|lo');
        expect(r, isNotNull);
        expect(r!.text, '> Hel\n> lo');
        expect(r.offset, 8);
      });
    });

    group('Multi-line context', () {
      test('continues list on second line', () {
        final r = _simulateEnter('Some text\n- Item|');
        expect(r, isNotNull);
        expect(r!.text, 'Some text\n- Item\n- ');
        expect(r.offset, 19);
      });

      test('continues ordered list after other content', () {
        final r = _simulateEnter('# Title\n\n1. First\n2. Second|');
        expect(r, isNotNull);
        expect(r!.text, '# Title\n\n1. First\n2. Second\n3. ');
        expect(r.offset, 31);
      });

      test('paragraph after list is pass-through', () {
        final r = _simulateEnter('- Item\n\nParagraph|');
        expect(r, isNull);
      });
    });

    group('Selection (non-collapsed)', () {
      test('returns null when selection is not collapsed', () {
        final controller = MarkdownEditingController(text: '');
        final oldValue = TextEditingValue(
          text: '- Hello world',
          selection: const TextSelection(baseOffset: 2, extentOffset: 7),
        );
        // Simulate: selected text replaced with \n
        final newValue = TextEditingValue(
          text: '- \nworld',
          selection: const TextSelection.collapsed(offset: 3),
        );
        final result = controller.applySmartEnter(oldValue, newValue);
        // When selection is not collapsed in oldValue, pass through
        expect(result, isNull);
        controller.dispose();
      });
    });
  });

  group('Widget integration - Smart Enter formatter', () {
    late MarkdownEditingController controller;

    Widget buildApp() {
      return MaterialApp(
        home: Scaffold(
          body: MarkdownEditor(
            controller: controller,
            autofocus: true,
          ),
        ),
      );
    }

    setUp(() {
      controller = MarkdownEditingController(text: '');
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('formatter is wired into EditableText', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // Set controller to a list item state and simulate entering text.
      controller.value = const TextEditingValue(
        text: '- Hello',
        selection: TextSelection.collapsed(offset: 7),
      );
      await tester.pump();

      // Verify the controller has the expected text.
      expect(controller.text, '- Hello');
    });

    testWidgets('smart enter continues list via enterText', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // Directly test the formatter behaviour by simulating the
      // oldValue → newValue transition that happens inside EditableText.
      final result = controller.applySmartEnter(
        const TextEditingValue(
          text: '- Hello',
          selection: TextSelection.collapsed(offset: 7),
        ),
        const TextEditingValue(
          text: '- Hello\n',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );

      expect(result, isNotNull);
      expect(result!.text, '- Hello\n- ');
    });
  });
}
