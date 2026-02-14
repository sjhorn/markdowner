import 'package:flutter_test/flutter_test.dart';
import 'package:petitparser/reflection.dart';

import 'package:markdowner/markdowner.dart';

void main() {
  group('PetitParser grammar linter', () {
    test('grammar has no linter issues', () {
      final grammar = MarkdownGrammarDefinition();
      final parser = grammar.build();
      final issues = linter(parser);
      expect(issues, isEmpty, reason: 'Grammar linter found issues: $issues');
    });

    test('parser definition has no linter issues', () {
      final parserDef = MarkdownParserDefinition();
      final parser = parserDef.build();
      final issues = linter(parser);
      expect(issues, isEmpty, reason: 'Parser linter found issues: $issues');
    });
  });
}
