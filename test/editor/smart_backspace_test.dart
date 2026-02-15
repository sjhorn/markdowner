import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/editor/markdown_editing_controller.dart';

/// Helper to simulate pressing Backspace at cursor position in [textWithCursor].
///
/// [textWithCursor] contains a `|` to mark cursor position.
/// Returns the result of [applySmartBackspace] as (text, cursorOffset),
/// or null if pass-through.
({String text, int offset})? _simulateBackspace(String textWithCursor) {
  final cursorPos = textWithCursor.indexOf('|');
  assert(cursorPos != -1, 'text must contain | to mark cursor position');
  final oldText = textWithCursor.replaceFirst('|', '');

  final oldValue = TextEditingValue(
    text: oldText,
    selection: TextSelection.collapsed(offset: cursorPos),
  );

  // Simulate what the platform does: delete one character before cursor.
  assert(cursorPos > 0, 'cursor must be after at least one character');
  final newText =
      oldText.substring(0, cursorPos - 1) + oldText.substring(cursorPos);
  final newValue = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: cursorPos - 1),
  );

  final controller = MarkdownEditingController(text: '');
  final result = controller.applySmartBackspace(oldValue, newValue);
  controller.dispose();

  if (result == null) return null;
  return (text: result.text, offset: result.selection.baseOffset);
}

void main() {
  group('Smart Backspace', () {
    group('Backspace at list content start', () {
      test('removes - prefix', () {
        final r = _simulateBackspace('- |Hello');
        expect(r, isNotNull);
        expect(r!.text, 'Hello');
        expect(r.offset, 0);
      });

      test('removes * prefix', () {
        final r = _simulateBackspace('* |Hello');
        expect(r, isNotNull);
        expect(r!.text, 'Hello');
        expect(r.offset, 0);
      });

      test('removes + prefix', () {
        final r = _simulateBackspace('+ |Hello');
        expect(r, isNotNull);
        expect(r!.text, 'Hello');
        expect(r.offset, 0);
      });

      test('removes ordered list 1. prefix', () {
        final r = _simulateBackspace('1. |Hello');
        expect(r, isNotNull);
        expect(r!.text, 'Hello');
        expect(r.offset, 0);
      });

      test('removes ordered list 3) prefix', () {
        final r = _simulateBackspace('3) |Hello');
        expect(r, isNotNull);
        expect(r!.text, 'Hello');
        expect(r.offset, 0);
      });

      test('removes task list prefix', () {
        final r = _simulateBackspace('- [ ] |Hello');
        expect(r, isNotNull);
        expect(r!.text, 'Hello');
        expect(r.offset, 0);
      });
    });

    group('Backspace at blockquote content start', () {
      test('removes > prefix', () {
        final r = _simulateBackspace('> |Hello');
        expect(r, isNotNull);
        expect(r!.text, 'Hello');
        expect(r.offset, 0);
      });
    });

    group('Backspace at heading content start', () {
      test('removes # prefix', () {
        final r = _simulateBackspace('# |Hello');
        expect(r, isNotNull);
        expect(r!.text, 'Hello');
        expect(r.offset, 0);
      });

      test('removes ### prefix', () {
        final r = _simulateBackspace('### |Hello');
        expect(r, isNotNull);
        expect(r!.text, 'Hello');
        expect(r.offset, 0);
      });
    });

    group('Backspace NOT at content start', () {
      test('returns null for mid-word backspace', () {
        final r = _simulateBackspace('- Hel|lo');
        expect(r, isNull);
      });

      test('returns null for end-of-line backspace', () {
        final r = _simulateBackspace('- Hello|');
        expect(r, isNull);
      });

      test('returns null for plain text', () {
        final r = _simulateBackspace('Hel|lo');
        expect(r, isNull);
      });
    });

    group('Multi-line scenarios', () {
      test('removes prefix on second line only', () {
        final r = _simulateBackspace('Some text\n- |Hello');
        expect(r, isNotNull);
        expect(r!.text, 'Some text\nHello');
        expect(r.offset, 10);
      });

      test('removes heading on second line', () {
        final r = _simulateBackspace('First line\n## |Title');
        expect(r, isNotNull);
        expect(r!.text, 'First line\nTitle');
        expect(r.offset, 11);
      });

      test('removes blockquote on second line', () {
        final r = _simulateBackspace('First line\n> |Quote');
        expect(r, isNotNull);
        expect(r!.text, 'First line\nQuote');
        expect(r.offset, 11);
      });

      test('returns null for non-prefix second line', () {
        final r = _simulateBackspace('First line\nHel|lo');
        expect(r, isNull);
      });
    });

    group('Empty prefix lines', () {
      test('removes empty - prefix', () {
        final r = _simulateBackspace('- |');
        expect(r, isNotNull);
        expect(r!.text, '');
        expect(r.offset, 0);
      });

      test('removes empty > prefix', () {
        final r = _simulateBackspace('> |');
        expect(r, isNotNull);
        expect(r!.text, '');
        expect(r.offset, 0);
      });

      test('removes empty # prefix', () {
        final r = _simulateBackspace('# |');
        expect(r, isNotNull);
        expect(r!.text, '');
        expect(r.offset, 0);
      });
    });

    group('Selection (non-collapsed)', () {
      test('returns null when selection is not collapsed', () {
        final controller = MarkdownEditingController(text: '');
        final oldValue = TextEditingValue(
          text: '- Hello',
          selection: const TextSelection(baseOffset: 2, extentOffset: 5),
        );
        final newValue = TextEditingValue(
          text: '- lo',
          selection: const TextSelection.collapsed(offset: 2),
        );
        final result = controller.applySmartBackspace(oldValue, newValue);
        expect(result, isNull);
        controller.dispose();
      });
    });
  });
}
