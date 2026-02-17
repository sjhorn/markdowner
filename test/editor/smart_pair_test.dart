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

  group('applySmartPairCompletion', () {
    group('backtick pair', () {
      test('typing ` auto-closes to `` with cursor between', () {
        // Simulates: user typed ` at offset 5 in "Hello"
        final oldValue = const TextEditingValue(
          text: 'Hello\n',
          selection: TextSelection.collapsed(offset: 5),
        );
        final newValue = const TextEditingValue(
          text: 'Hello`\n',
          selection: TextSelection.collapsed(offset: 6),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNotNull);
        expect(result!.text, 'Hello``\n');
        expect(result.selection,
            const TextSelection.collapsed(offset: 6));
      });

      test('typing ` mid-word does not auto-close', () {
        final oldValue = const TextEditingValue(
          text: 'Hello\n',
          selection: TextSelection.collapsed(offset: 3),
        );
        final newValue = const TextEditingValue(
          text: 'Hel`lo\n',
          selection: TextSelection.collapsed(offset: 4),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        // Should auto-close even mid-word for backtick
        expect(result, isNotNull);
        expect(result!.text, 'Hel``lo\n');
      });
    });

    group('bracket pair []', () {
      test('typing [ auto-closes to [](url) with cursor inside []', () {
        final oldValue = const TextEditingValue(
          text: 'Hello \n',
          selection: TextSelection.collapsed(offset: 6),
        );
        final newValue = const TextEditingValue(
          text: 'Hello [\n',
          selection: TextSelection.collapsed(offset: 7),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNotNull);
        expect(result!.text, 'Hello [](url)\n');
        expect(result.selection,
            const TextSelection.collapsed(offset: 7));
      });
    });

    group('image ![] pair', () {
      test('typing [ after ! auto-closes to ![](url)', () {
        // User already typed !, now types [
        final oldValue = const TextEditingValue(
          text: 'Hello !\n',
          selection: TextSelection.collapsed(offset: 7),
        );
        final newValue = const TextEditingValue(
          text: 'Hello ![\n',
          selection: TextSelection.collapsed(offset: 8),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNotNull);
        expect(result!.text, 'Hello ![](url)\n');
        expect(result.selection,
            const TextSelection.collapsed(offset: 8));
      });
    });

    group('no auto-close inside inline code', () {
      test('typing [ inside backticks does not auto-close', () {
        final oldValue = const TextEditingValue(
          text: '`code\n',
          selection: TextSelection.collapsed(offset: 5),
        );
        final newValue = const TextEditingValue(
          text: '`code[\n',
          selection: TextSelection.collapsed(offset: 6),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNull);
      });
    });

    group('no auto-close inside code block', () {
      test('typing [ inside code block does not auto-close', () {
        final oldValue = const TextEditingValue(
          text: '```\ncode\n```\n',
          selection: TextSelection.collapsed(offset: 8),
        );
        final newValue = const TextEditingValue(
          text: '```\ncode[\n```\n',
          selection: TextSelection.collapsed(offset: 9),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNull);
      });

      test('typing ` inside code block does not auto-close', () {
        final oldValue = const TextEditingValue(
          text: '```\ncode\n```\n',
          selection: TextSelection.collapsed(offset: 8),
        );
        final newValue = const TextEditingValue(
          text: '```\ncode`\n```\n',
          selection: TextSelection.collapsed(offset: 9),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNull);
      });
    });

    group('double-delimiter pairs', () {
      test('typing second * after * auto-closes **|**', () {
        // User already typed *, now typing second *
        final oldValue = const TextEditingValue(
          text: 'Hello *\n',
          selection: TextSelection.collapsed(offset: 7),
        );
        final newValue = const TextEditingValue(
          text: 'Hello **\n',
          selection: TextSelection.collapsed(offset: 8),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNotNull);
        expect(result!.text, 'Hello ****\n');
        expect(result.selection,
            const TextSelection.collapsed(offset: 8));
      });

      test('typing second ~ after ~ auto-closes ~~|~~', () {
        final oldValue = const TextEditingValue(
          text: 'Hello ~\n',
          selection: TextSelection.collapsed(offset: 7),
        );
        final newValue = const TextEditingValue(
          text: 'Hello ~~\n',
          selection: TextSelection.collapsed(offset: 8),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNotNull);
        expect(result!.text, 'Hello ~~~~\n');
        expect(result.selection,
            const TextSelection.collapsed(offset: 8));
      });
    });

    group('non-triggering cases', () {
      test('typing regular character does not trigger', () {
        final oldValue = const TextEditingValue(
          text: 'Hello\n',
          selection: TextSelection.collapsed(offset: 5),
        );
        final newValue = const TextEditingValue(
          text: 'Hellox\n',
          selection: TextSelection.collapsed(offset: 6),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNull);
      });

      test('deletion does not trigger', () {
        final oldValue = const TextEditingValue(
          text: 'Hello`\n',
          selection: TextSelection.collapsed(offset: 6),
        );
        final newValue = const TextEditingValue(
          text: 'Hello\n',
          selection: TextSelection.collapsed(offset: 5),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNull);
      });

      test('multi-char insertion does not trigger', () {
        final oldValue = const TextEditingValue(
          text: 'Hello\n',
          selection: TextSelection.collapsed(offset: 5),
        );
        final newValue = const TextEditingValue(
          text: 'Hello``\n',
          selection: TextSelection.collapsed(offset: 7),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNull);
      });
    });

    group('== highlight pair', () {
      test('typing second = auto-closes to ==== with cursor between', () {
        // Simulates: user typed = at position 6 in "Hello=" (so now "Hello==")
        final oldValue = const TextEditingValue(
          text: 'Hello=',
          selection: TextSelection.collapsed(offset: 6),
        );
        final newValue = const TextEditingValue(
          text: 'Hello==',
          selection: TextSelection.collapsed(offset: 7),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNotNull);
        expect(result!.text, 'Hello====');
        expect(result.selection.baseOffset, 7); // cursor between ==
      });

      test('first = does not trigger auto-close', () {
        final oldValue = const TextEditingValue(
          text: 'Hello',
          selection: TextSelection.collapsed(offset: 5),
        );
        final newValue = const TextEditingValue(
          text: 'Hello=',
          selection: TextSelection.collapsed(offset: 6),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNull);
      });

      test('== suppressed inside code block', () {
        final oldValue = const TextEditingValue(
          text: '```\nx=',
          selection: TextSelection.collapsed(offset: 6),
        );
        final newValue = const TextEditingValue(
          text: '```\nx==',
          selection: TextSelection.collapsed(offset: 7),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNull);
      });
    });

    group('^ superscript pair', () {
      test('typing ^ auto-closes to ^^ with cursor between', () {
        final oldValue = const TextEditingValue(
          text: 'x',
          selection: TextSelection.collapsed(offset: 1),
        );
        final newValue = const TextEditingValue(
          text: 'x^',
          selection: TextSelection.collapsed(offset: 2),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNotNull);
        expect(result!.text, 'x^^');
        expect(result.selection.baseOffset, 2); // cursor between ^
      });

      test('^ suppressed inside code block', () {
        final oldValue = const TextEditingValue(
          text: '```\ncode',
          selection: TextSelection.collapsed(offset: 8),
        );
        final newValue = const TextEditingValue(
          text: '```\ncode^',
          selection: TextSelection.collapsed(offset: 9),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        expect(result, isNull);
      });
    });

    group('~ subscript - no auto-close', () {
      test('single ~ does not auto-close (avoids ~~ conflict)', () {
        final oldValue = const TextEditingValue(
          text: 'H2O',
          selection: TextSelection.collapsed(offset: 1),
        );
        final newValue = const TextEditingValue(
          text: 'H~2O',
          selection: TextSelection.collapsed(offset: 2),
        );

        final result =
            controller.applySmartPairCompletion(oldValue, newValue);

        // Single ~ should NOT auto-close (that's ~~ strikethrough territory)
        expect(result, isNull);
      });
    });
  });
}
