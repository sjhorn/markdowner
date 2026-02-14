import 'dart:async';

import 'package:flutter/widgets.dart';

/// A snapshot of the editor state at a point in time.
class MarkdownSnapshot {
  final String markdown;
  final TextSelection selection;
  final DateTime timestamp;

  MarkdownSnapshot({
    required this.markdown,
    required this.selection,
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

  /// Whether there is a previous state to undo to.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there is a state to redo to.
  bool get canRedo => _redoStack.isNotEmpty;

  /// The number of snapshots in the undo stack.
  int get undoStackSize => _undoStack.length;

  /// The number of snapshots in the redo stack.
  int get redoStackSize => _redoStack.length;

  /// Record a change. Starts or resets the 1-second coalesce timer.
  /// When the timer fires, the pending snapshot is committed to the undo stack.
  void recordChange(String markdown, TextSelection selection) {
    // On first change after an undo/redo or after initial state,
    // clear the redo stack since we've branched.
    if (_pending == null && _redoStack.isNotEmpty) {
      _redoStack.clear();
    } else if (_pending != null) {
      _redoStack.clear();
    }

    _pending = MarkdownSnapshot(markdown: markdown, selection: selection);
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
    _undoStack.add(_pending!);
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
    ));

    return _undoStack.removeLast();
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
    ));

    return _redoStack.removeLast();
  }

  /// Cancel the coalesce timer and release resources.
  void dispose() {
    _coalesceTimer?.cancel();
  }
}
