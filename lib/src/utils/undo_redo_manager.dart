import 'dart:async';

import 'package:flutter/widgets.dart';

/// A snapshot of the editor state at a point in time.
class MarkdownSnapshot {
  final String markdown;
  final TextSelection selection;
  final DateTime timestamp;
  final String name;

  MarkdownSnapshot({
    required this.markdown,
    required this.selection,
    required this.name,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Manages undo/redo stacks for the markdown editor.
///
/// Changes are coalesced: rapid edits within 1 second are grouped into a
/// single undo step. Call [breakGroup] to force a snapshot boundary.
class UndoRedoManager {
  static const int maxStackSize = 200;
  static const Duration coalesceDuration = Duration(seconds: 1);

  final List<MarkdownSnapshot> _undoStack = [];
  final List<MarkdownSnapshot> _redoStack = [];
  Timer? _coalesceTimer;
  MarkdownSnapshot? _pending;
  MarkdownSnapshot? _lastCommittedState;

  /// Whether there is a previous state to undo to.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there is a state to redo to.
  bool get canRedo => _redoStack.isNotEmpty;

  /// The number of snapshots in the undo stack.
  int get undoStackSize => _undoStack.length;

  /// The number of snapshots in the redo stack.
  int get redoStackSize => _redoStack.length;

  /// Set the initial editor state. Call once when the editor is initialized
  /// so the undo system knows what to restore to on the first undo.
  void setInitialState(String markdown, TextSelection selection) {
    _lastCommittedState = MarkdownSnapshot(
      markdown: markdown,
      selection: selection,
      name: 'Initial',
    );
  }

  /// Record a change. Starts or resets the 1-second coalesce timer.
  /// When the timer fires, the pending snapshot is committed to the undo stack.
  ///
  /// Selection-only changes (where the text hasn't changed) are ignored.
  void recordChange(String markdown, TextSelection selection) {
    // Skip no-op changes where only the selection moved
    final referenceText = _pending?.markdown ?? _lastCommittedState?.markdown;
    if (referenceText != null && markdown == referenceText) return;

    _redoStack.clear();
    _pending = MarkdownSnapshot(
      markdown: markdown,
      selection: selection,
      name: _describeDiff(_lastCommittedState?.markdown, markdown),
    );
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(coalesceDuration, _commitPending);
  }

  /// Force-commit the pending snapshot immediately.
  void breakGroup() {
    if (_pending != null) {
      _coalesceTimer?.cancel();
      _commitPending();
    }
  }

  void _commitPending() {
    if (_pending == null) return;
    // Push the state BEFORE this edit group to the undo stack
    if (_lastCommittedState != null) {
      _undoStack.add(_lastCommittedState!);
    }
    _lastCommittedState = _pending;
    _pending = null;

    // Trim if over max size
    while (_undoStack.length > maxStackSize) {
      _undoStack.removeAt(0);
    }
  }

  /// Undo: returns the previous snapshot, or null if nothing to undo.
  ///
  /// [currentMarkdown] and [currentSelection] represent the current state
  /// which will be pushed onto the redo stack.
  MarkdownSnapshot? undo(String currentMarkdown, TextSelection currentSelection) {
    // Commit any pending changes first
    if (_pending != null) {
      _coalesceTimer?.cancel();
      _commitPending();
    }

    if (_undoStack.isEmpty) return null;

    // Push current state to redo
    _redoStack.add(MarkdownSnapshot(
      markdown: currentMarkdown,
      selection: currentSelection,
      name: _describeDiff(_undoStack.lastOrNull?.markdown, currentMarkdown),
    ));

    final restored = _undoStack.removeLast();
    _lastCommittedState = restored;
    return restored;
  }

  /// Redo: returns the next snapshot, or null if nothing to redo.
  ///
  /// [currentMarkdown] and [currentSelection] represent the current state
  /// which will be pushed onto the undo stack.
  MarkdownSnapshot? redo(String currentMarkdown, TextSelection currentSelection) {
    if (_redoStack.isEmpty) return null;

    // Push current state to undo
    _undoStack.add(MarkdownSnapshot(
      markdown: currentMarkdown,
      selection: currentSelection,
      name: _describeDiff(_lastCommittedState?.markdown, currentMarkdown),
    ));

    final restored = _redoStack.removeLast();
    _lastCommittedState = restored;
    return restored;
  }

  /// Snapshot names from the undo stack, most recent first.
  List<String> get undoNames =>
      _undoStack.reversed.map((s) => s.name).toList();

  /// Snapshot names from the redo stack, most recent first.
  List<String> get redoNames =>
      _redoStack.reversed.map((s) => s.name).toList();

  /// Perform [count] consecutive undos, returning the final restored snapshot.
  MarkdownSnapshot? undoSteps(
      int count, String currentMarkdown, TextSelection currentSelection) {
    if (count <= 0) return null;
    MarkdownSnapshot? result;
    var markdown = currentMarkdown;
    var selection = currentSelection;
    for (var i = 0; i < count; i++) {
      final snapshot = undo(markdown, selection);
      if (snapshot == null) break;
      result = snapshot;
      markdown = snapshot.markdown;
      selection = snapshot.selection;
    }
    return result;
  }

  /// Perform [count] consecutive redos, returning the final restored snapshot.
  MarkdownSnapshot? redoSteps(
      int count, String currentMarkdown, TextSelection currentSelection) {
    if (count <= 0) return null;
    MarkdownSnapshot? result;
    var markdown = currentMarkdown;
    var selection = currentSelection;
    for (var i = 0; i < count; i++) {
      final snapshot = redo(markdown, selection);
      if (snapshot == null) break;
      result = snapshot;
      markdown = snapshot.markdown;
      selection = snapshot.selection;
    }
    return result;
  }

  /// Generate a human-readable name describing the diff between two states.
  static String _describeDiff(String? oldText, String newText) {
    if (oldText == null) return 'Initial';
    if (newText.length > oldText.length) {
      final inserted = newText.length - oldText.length;
      // Try to find the inserted text by comparing from the start
      var commonPrefix = 0;
      while (commonPrefix < oldText.length &&
          commonPrefix < newText.length &&
          oldText[commonPrefix] == newText[commonPrefix]) {
        commonPrefix++;
      }
      final addedText =
          newText.substring(commonPrefix, commonPrefix + inserted);
      if (addedText.trim().isEmpty) return 'Added whitespace';
      var display = addedText;
      if (display.length > 12) {
        display = '${display.substring(0, 12)}...';
      }
      return "Typed '$display'";
    }
    if (newText.length < oldText.length) {
      final deleted = oldText.length - newText.length;
      return 'Deleted $deleted chars';
    }
    return 'Edited text';
  }

  /// Cancel the coalesce timer and release resources.
  void dispose() {
    _coalesceTimer?.cancel();
  }
}
