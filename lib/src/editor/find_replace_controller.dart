import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Controller for find and replace functionality.
///
/// Maintains search state including the query, matches, and current match
/// index. Notifies listeners when state changes.
class FindReplaceController extends ChangeNotifier {
  String _query = '';
  bool _caseSensitive = false;
  List<TextRange> _matches = [];
  int _currentMatchIndex = -1;

  /// The current search query.
  String get query => _query;

  /// Whether the search is case sensitive.
  bool get caseSensitive => _caseSensitive;

  /// All match ranges in the text.
  List<TextRange> get matches => List.unmodifiable(_matches);

  /// Index of the currently highlighted match, or -1 if no matches.
  int get currentMatchIndex => _currentMatchIndex;

  /// Total number of matches.
  int get matchCount => _matches.length;

  /// The currently highlighted match range, or null.
  TextRange? get currentMatch =>
      _currentMatchIndex >= 0 && _currentMatchIndex < _matches.length
          ? _matches[_currentMatchIndex]
          : null;

  /// Search for [query] in [text].
  ///
  /// Populates [matches] with all occurrences and sets [currentMatchIndex]
  /// to 0 if any matches are found.
  void search(String query, String text, {bool caseSensitive = false}) {
    _query = query;
    _caseSensitive = caseSensitive;

    if (query.isEmpty) {
      _matches = [];
      _currentMatchIndex = -1;
      notifyListeners();
      return;
    }

    final searchText = caseSensitive ? text : text.toLowerCase();
    final searchQuery = caseSensitive ? query : query.toLowerCase();

    _matches = [];
    var start = 0;
    while (start < searchText.length) {
      final index = searchText.indexOf(searchQuery, start);
      if (index < 0) break;
      _matches.add(TextRange(start: index, end: index + query.length));
      start = index + 1;
    }

    _currentMatchIndex = _matches.isNotEmpty ? 0 : -1;
    notifyListeners();
  }

  /// Move to the next match (wraps around).
  void nextMatch() {
    if (_matches.isEmpty) return;
    _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    notifyListeners();
  }

  /// Move to the previous match (wraps around).
  void previousMatch() {
    if (_matches.isEmpty) return;
    _currentMatchIndex =
        (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    notifyListeners();
  }

  /// Replace the current match in [text] with [replacement].
  ///
  /// Returns the new text after replacement. Does not update [text] in the
  /// controller — the caller should update the editing controller.
  String replaceCurrentMatch(String text, String replacement) {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _matches.length) {
      return text;
    }
    final match = _matches[_currentMatchIndex];
    return text.substring(0, match.start) +
        replacement +
        text.substring(match.end);
  }

  /// Replace all matches in [text] with [replacement].
  ///
  /// Returns the new text after all replacements.
  String replaceAll(String text, String replacement) {
    if (_matches.isEmpty) return text;

    final buffer = StringBuffer();
    var lastEnd = 0;
    for (final match in _matches) {
      buffer.write(text.substring(lastEnd, match.start));
      buffer.write(replacement);
      lastEnd = match.end;
    }
    buffer.write(text.substring(lastEnd));
    return buffer.toString();
  }

  /// Reset all search state.
  void clear() {
    _query = '';
    _caseSensitive = false;
    _matches = [];
    _currentMatchIndex = -1;
    notifyListeners();
  }
}
