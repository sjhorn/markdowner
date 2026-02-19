/// Statistics for a markdown document.
///
/// Counts words, characters, lines, and estimates reading time based on
/// the raw markdown text (not rendered output).
class DocumentStats {
  /// Number of words in the document.
  final int wordCount;

  /// Total number of characters including whitespace.
  final int characterCount;

  /// Number of characters excluding whitespace.
  final int characterCountWithoutSpaces;

  /// Number of lines (at least 1 for any text).
  final int lineCount;

  /// Estimated reading time based on 200 words per minute.
  final Duration readingTime;

  const DocumentStats({
    required this.wordCount,
    required this.characterCount,
    required this.characterCountWithoutSpaces,
    required this.lineCount,
    required this.readingTime,
  });

  /// Compute stats from raw text.
  factory DocumentStats.fromText(String text) {
    final characterCount = text.length;
    final characterCountWithoutSpaces =
        text.replaceAll(RegExp(r'\s'), '').length;

    final lineCount = text.isEmpty ? 1 : '\n'.allMatches(text).length + 1;

    final words = text.split(RegExp(r'\s+'));
    final wordCount =
        words.where((w) => w.isNotEmpty).length;

    // 200 words per minute
    const wordsPerMinute = 200;
    final readingTimeMs =
        wordCount > 0 ? (wordCount / wordsPerMinute * 60 * 1000).round() : 0;

    return DocumentStats(
      wordCount: wordCount,
      characterCount: characterCount,
      characterCountWithoutSpaces: characterCountWithoutSpaces,
      lineCount: lineCount,
      readingTime: Duration(milliseconds: readingTimeMs),
    );
  }
}
