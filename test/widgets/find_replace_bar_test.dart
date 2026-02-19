import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:markdowner/src/widgets/markdown_editor.dart';

bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

LogicalKeyboardKey get _modifierKey =>
    _isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;

Future<void> _openFindBar(WidgetTester tester) async {
  await tester.sendKeyDownEvent(_modifierKey);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(_modifierKey);
  await tester.pump();
}

Future<void> _openFindReplaceBar(WidgetTester tester) async {
  await tester.sendKeyDownEvent(_modifierKey);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
  await tester.sendKeyUpEvent(_modifierKey);
  await tester.pump();
}

void main() {
  Widget buildApp({
    String? initialMarkdown,
    bool readOnly = false,
    GlobalKey<MarkdownEditorState>? editorKey,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MarkdownEditor(
          key: editorKey,
          initialMarkdown: initialMarkdown,
          readOnly: readOnly,
          autofocus: true,
        ),
      ),
    );
  }

  group('Find bar shortcuts', () {
    testWidgets('Cmd+F shows find bar', (tester) async {
      await tester.pumpWidget(buildApp(initialMarkdown: 'hello world hello\n'));
      await tester.pump();

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      await _openFindBar(tester);

      expect(find.byKey(const Key('find_search_field')), findsOneWidget);
    });

    testWidgets('Cmd+H shows find+replace bar', (tester) async {
      await tester.pumpWidget(buildApp(initialMarkdown: 'hello world\n'));
      await tester.pump();

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      await _openFindReplaceBar(tester);

      expect(find.byKey(const Key('find_search_field')), findsOneWidget);
      expect(find.byKey(const Key('find_replace_field')), findsOneWidget);
    });

    testWidgets('Escape closes find bar', (tester) async {
      await tester.pumpWidget(buildApp(initialMarkdown: 'hello\n'));
      await tester.pump();

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      await _openFindBar(tester);
      expect(find.byKey(const Key('find_search_field')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byKey(const Key('find_search_field')), findsNothing);
    });
  });

  group('Find bar interactions', () {
    testWidgets('typing query triggers search and shows match count',
        (tester) async {
      await tester.pumpWidget(buildApp(initialMarkdown: 'hello world hello\n'));
      await tester.pump();

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      await _openFindBar(tester);

      await tester.enterText(
          find.byKey(const Key('find_search_field')), 'hello');
      await tester.pump();

      expect(find.text('1 of 2'), findsOneWidget);
    });

    testWidgets('next/previous buttons navigate matches', (tester) async {
      await tester.pumpWidget(buildApp(initialMarkdown: 'aa bb aa cc aa\n'));
      await tester.pump();

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      await _openFindBar(tester);

      await tester.enterText(
          find.byKey(const Key('find_search_field')), 'aa');
      await tester.pump();

      expect(find.text('1 of 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('find_next_button')));
      await tester.pump();

      expect(find.text('2 of 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('find_prev_button')));
      await tester.pump();

      expect(find.text('1 of 3'), findsOneWidget);
    });

    testWidgets('close button hides bar', (tester) async {
      await tester.pumpWidget(buildApp(initialMarkdown: 'hello\n'));
      await tester.pump();

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      await _openFindBar(tester);
      expect(find.byKey(const Key('find_search_field')), findsOneWidget);

      await tester.tap(find.byKey(const Key('find_close_button')));
      await tester.pump();

      expect(find.byKey(const Key('find_search_field')), findsNothing);
    });

    testWidgets('replace button replaces current match', (tester) async {
      final key = GlobalKey<MarkdownEditorState>();
      await tester.pumpWidget(buildApp(
        initialMarkdown: 'foo bar foo\n',
        editorKey: key,
      ));
      await tester.pump();

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      await _openFindReplaceBar(tester);

      await tester.enterText(
          find.byKey(const Key('find_search_field')), 'foo');
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('find_replace_field')), 'baz');
      await tester.pump();

      await tester.tap(find.byKey(const Key('find_replace_button')));
      await tester.pump();

      expect(key.currentState!.controller.text, equals('baz bar foo\n'));
    });

    testWidgets('replace all replaces all matches', (tester) async {
      final key = GlobalKey<MarkdownEditorState>();
      await tester.pumpWidget(buildApp(
        initialMarkdown: 'foo bar foo baz foo\n',
        editorKey: key,
      ));
      await tester.pump();

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      await _openFindReplaceBar(tester);

      await tester.enterText(
          find.byKey(const Key('find_search_field')), 'foo');
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('find_replace_field')), 'x');
      await tester.pump();

      await tester.tap(find.byKey(const Key('find_replace_all_button')));
      await tester.pump();

      expect(key.currentState!.controller.text, equals('x bar x baz x\n'));
    });
  });
}
