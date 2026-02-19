import 'package:flutter_test/flutter_test.dart';

import 'package:markdowner/src/editor/find_replace_controller.dart';

void main() {
  group('FindReplaceController', () {
    late FindReplaceController controller;

    setUp(() {
      controller = FindReplaceController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('search finds all occurrences case insensitive', () {
      controller.search('hello', 'Hello world hello HELLO');
      expect(controller.matchCount, equals(3));
      expect(controller.currentMatchIndex, equals(0));
    });

    test('search finds matches case sensitive', () {
      controller.search('hello', 'Hello world hello HELLO',
          caseSensitive: true);
      expect(controller.matchCount, equals(1));
      expect(controller.matches[0].start, equals(12));
    });

    test('nextMatch cycles forward', () {
      controller.search('a', 'a b a c a');
      expect(controller.currentMatchIndex, equals(0));

      controller.nextMatch();
      expect(controller.currentMatchIndex, equals(1));

      controller.nextMatch();
      expect(controller.currentMatchIndex, equals(2));

      // Wraps around
      controller.nextMatch();
      expect(controller.currentMatchIndex, equals(0));
    });

    test('previousMatch cycles backward', () {
      controller.search('a', 'a b a c a');
      expect(controller.currentMatchIndex, equals(0));

      // Wraps around to last
      controller.previousMatch();
      expect(controller.currentMatchIndex, equals(2));

      controller.previousMatch();
      expect(controller.currentMatchIndex, equals(1));
    });

    test('empty query clears matches', () {
      controller.search('hello', 'hello world');
      expect(controller.matchCount, equals(1));

      controller.search('', 'hello world');
      expect(controller.matchCount, equals(0));
      expect(controller.currentMatchIndex, equals(-1));
    });

    test('replaceCurrentMatch replaces correctly and returns new text', () {
      controller.search('foo', 'foo bar foo');
      expect(controller.currentMatchIndex, equals(0));

      final newText = controller.replaceCurrentMatch('foo bar foo', 'baz');
      expect(newText, equals('baz bar foo'));
    });

    test('replaceAll replaces all occurrences', () {
      controller.search('foo', 'foo bar foo baz foo');
      final newText = controller.replaceAll('foo bar foo baz foo', 'x');
      expect(newText, equals('x bar x baz x'));
    });

    test('no matches returns empty list', () {
      controller.search('xyz', 'hello world');
      expect(controller.matchCount, equals(0));
      expect(controller.currentMatchIndex, equals(-1));
      expect(controller.currentMatch, isNull);
    });

    test('single character query works', () {
      controller.search('a', 'abcabc');
      expect(controller.matchCount, equals(2));
      expect(controller.matches[0].start, equals(0));
      expect(controller.matches[1].start, equals(3));
    });

    test('query at document start found', () {
      controller.search('hello', 'hello world');
      expect(controller.matches[0].start, equals(0));
      expect(controller.matches[0].end, equals(5));
    });

    test('query at document end found', () {
      controller.search('world', 'hello world');
      expect(controller.matches[0].start, equals(6));
      expect(controller.matches[0].end, equals(11));
    });

    test('clear resets all state', () {
      controller.search('hello', 'hello world hello');
      controller.nextMatch();
      expect(controller.matchCount, equals(2));

      controller.clear();
      expect(controller.query, equals(''));
      expect(controller.matchCount, equals(0));
      expect(controller.currentMatchIndex, equals(-1));
    });

    test('replaceCurrentMatch updates matches after replacement', () {
      controller.search('foo', 'foo bar foo');
      final newText = controller.replaceCurrentMatch('foo bar foo', 'baz');

      // After replacement, re-search with new text
      controller.search('foo', newText);
      expect(controller.matchCount, equals(1));
    });

    test('notifies listeners on search', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.search('hello', 'hello world');
      expect(notified, isTrue);
    });

    test('notifies listeners on navigation', () {
      controller.search('a', 'a b a');

      var notified = false;
      controller.addListener(() => notified = true);

      controller.nextMatch();
      expect(notified, isTrue);
    });
  });
}
