import 'package:flutter_test/flutter_test.dart';

import 'package:markdowner/src/utils/document_stats.dart';

void main() {
  group('DocumentStats.fromText()', () {
    test('empty text: 0 words, 0 chars, 1 line, 0 duration', () {
      final stats = DocumentStats.fromText('');
      expect(stats.wordCount, equals(0));
      expect(stats.characterCount, equals(0));
      expect(stats.characterCountWithoutSpaces, equals(0));
      expect(stats.lineCount, equals(1));
      expect(stats.readingTime, equals(Duration.zero));
    });

    test('single word: 1 word, correct char counts', () {
      final stats = DocumentStats.fromText('hello');
      expect(stats.wordCount, equals(1));
      expect(stats.characterCount, equals(5));
      expect(stats.characterCountWithoutSpaces, equals(5));
      expect(stats.lineCount, equals(1));
    });

    test('multiple words on one line', () {
      final stats = DocumentStats.fromText('hello world foo');
      expect(stats.wordCount, equals(3));
      expect(stats.characterCount, equals(15));
      expect(stats.characterCountWithoutSpaces, equals(13));
      expect(stats.lineCount, equals(1));
    });

    test('multi-line: correct line count', () {
      final stats = DocumentStats.fromText('hello\nworld\nfoo');
      expect(stats.wordCount, equals(3));
      expect(stats.lineCount, equals(3));
    });

    test('trailing newline counts as extra line', () {
      final stats = DocumentStats.fromText('hello\n');
      expect(stats.lineCount, equals(2));
    });

    test('reading time: 200 words equals 1 minute', () {
      final words = List.generate(200, (i) => 'word').join(' ');
      final stats = DocumentStats.fromText(words);
      expect(stats.wordCount, equals(200));
      expect(stats.readingTime, equals(const Duration(minutes: 1)));
    });

    test('reading time: 100 words equals 30 seconds', () {
      final words = List.generate(100, (i) => 'word').join(' ');
      final stats = DocumentStats.fromText(words);
      expect(stats.wordCount, equals(100));
      expect(stats.readingTime, equals(const Duration(seconds: 30)));
    });

    test('mixed whitespace: tabs and multiple spaces counted correctly', () {
      final stats = DocumentStats.fromText('hello\t\tworld   foo');
      expect(stats.wordCount, equals(3));
    });

    test('markdown syntax counted as characters (raw text)', () {
      final stats = DocumentStats.fromText('**bold** text');
      expect(stats.wordCount, equals(2));
      expect(stats.characterCount, equals(13));
      // Stars are non-space characters
      expect(stats.characterCountWithoutSpaces, equals(12));
    });

    test('only whitespace has 0 words', () {
      final stats = DocumentStats.fromText('   \t  \n  ');
      expect(stats.wordCount, equals(0));
    });
  });
}
