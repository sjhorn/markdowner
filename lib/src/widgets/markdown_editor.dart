import 'package:flutter/material.dart';

import '../editor/markdown_editing_controller.dart';
import '../theme/markdown_editor_theme.dart';
import '../utils/undo_redo_manager.dart';

/// A WYSIWYG markdown editor widget with reveal/hide mechanics.
///
/// When the cursor is in a block, raw syntax is visible (revealed).
/// When the cursor leaves, syntax collapses and content renders with
/// rich formatting (collapsed).
class MarkdownEditor extends StatefulWidget {
  /// Initial markdown content. Ignored if [controller] is provided.
  final String? initialMarkdown;

  /// External controller. If provided, the widget does not manage its lifecycle.
  final MarkdownEditingController? controller;

  /// Called when the markdown text changes.
  final ValueChanged<String>? onChanged;

  /// Focus node. If not provided, the widget creates and manages its own.
  final FocusNode? focusNode;

  /// Theme for the editor. Falls back to [MarkdownEditorTheme.light()].
  final MarkdownEditorTheme? theme;

  /// Whether the editor is read-only.
  final bool readOnly;

  /// Whether to autofocus the editor on mount.
  final bool autofocus;

  /// Padding around the editing area.
  final EdgeInsets padding;

  const MarkdownEditor({
    super.key,
    this.initialMarkdown,
    this.controller,
    this.onChanged,
    this.focusNode,
    this.theme,
    this.readOnly = false,
    this.autofocus = false,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<MarkdownEditor> createState() => MarkdownEditorState();
}

class MarkdownEditorState extends State<MarkdownEditor> {
  late MarkdownEditingController _controller;
  late FocusNode _focusNode;
  late UndoRedoManager _undoRedoManager;
  final GlobalKey<EditableTextState> _editableKey = GlobalKey();
  late _TextSelectionDelegate _selectionDelegate;
  late TextSelectionGestureDetectorBuilder _gestureDetectorBuilder;
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _isUndoRedoInProgress = false;

  MarkdownEditingController get controller => _controller;
  UndoRedoManager get undoRedoManager => _undoRedoManager;

  /// Snapshot names from the undo stack, most recent first.
  List<String> get undoNames => _undoRedoManager.undoNames;

  /// Snapshot names from the redo stack, most recent first.
  List<String> get redoNames => _undoRedoManager.redoNames;

  /// Perform undo. Returns true if a state was restored.
  bool undo() {
    final snapshot = _undoRedoManager.undo(
      _controller.text,
      _controller.selection,
    );
    if (snapshot == null) return false;
    _isUndoRedoInProgress = true;
    _controller.value = TextEditingValue(
      text: snapshot.markdown,
      selection: snapshot.selection,
    );
    _isUndoRedoInProgress = false;
    return true;
  }

  /// Perform redo. Returns true if a state was restored.
  bool redo() {
    final snapshot = _undoRedoManager.redo(
      _controller.text,
      _controller.selection,
    );
    if (snapshot == null) return false;
    _isUndoRedoInProgress = true;
    _controller.value = TextEditingValue(
      text: snapshot.markdown,
      selection: snapshot.selection,
    );
    _isUndoRedoInProgress = false;
    return true;
  }

  /// Perform [count] consecutive undos. Returns true if any state was restored.
  bool undoSteps(int count) {
    final snapshot = _undoRedoManager.undoSteps(
      count,
      _controller.text,
      _controller.selection,
    );
    if (snapshot == null) return false;
    _isUndoRedoInProgress = true;
    _controller.value = TextEditingValue(
      text: snapshot.markdown,
      selection: snapshot.selection,
    );
    _isUndoRedoInProgress = false;
    return true;
  }

  /// Perform [count] consecutive redos. Returns true if any state was restored.
  bool redoSteps(int count) {
    final snapshot = _undoRedoManager.redoSteps(
      count,
      _controller.text,
      _controller.selection,
    );
    if (snapshot == null) return false;
    _isUndoRedoInProgress = true;
    _controller.value = TextEditingValue(
      text: snapshot.markdown,
      selection: snapshot.selection,
    );
    _isUndoRedoInProgress = false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _undoRedoManager = UndoRedoManager();
    _selectionDelegate = _TextSelectionDelegate(_editableKey);
    _gestureDetectorBuilder =
        TextSelectionGestureDetectorBuilder(delegate: _selectionDelegate);

    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = MarkdownEditingController(
        text: widget.initialMarkdown ?? '',
        theme: widget.theme,
      );
      _ownsController = true;
    }

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    _controller.addListener(_onControllerChanged);
    _undoRedoManager.setInitialState(
      _controller.text,
      _controller.selection,
    );
  }

  @override
  void didUpdateWidget(MarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onControllerChanged);

      if (_ownsController) {
        _controller.dispose();
        _ownsController = false;
      }

      if (widget.controller != null) {
        _controller = widget.controller!;
      } else {
        _controller = MarkdownEditingController(
          text: widget.initialMarkdown ?? '',
          theme: widget.theme,
        );
        _ownsController = true;
      }

      _controller.addListener(_onControllerChanged);
    }

    if (widget.focusNode != oldWidget.focusNode) {
      if (_ownsFocusNode) {
        _focusNode.dispose();
        _ownsFocusNode = false;
      }

      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
      } else {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      }
    }
  }

  void _onControllerChanged() {
    if (!_isUndoRedoInProgress) {
      _undoRedoManager.recordChange(
        _controller.text,
        _controller.selection,
      );
    }
    widget.onChanged?.call(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    _undoRedoManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? MarkdownEditorTheme.light();
    return Container(
      color: theme.backgroundColor,
      padding: widget.padding,
      child: _gestureDetectorBuilder.buildGestureDetector(
        behavior: HitTestBehavior.translucent,
        child: EditableText(
          key: _editableKey,
          rendererIgnoresPointer: true,
          controller: _controller,
          focusNode: _focusNode,
          style: theme.baseStyle,
          cursorColor: theme.cursorColor,
          selectionColor: theme.selectionColor,
          backgroundCursorColor: theme.cursorColor.withValues(alpha: 0.1),
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          maxLines: null,
          keyboardType: TextInputType.multiline,
        ),
      ),
    );
  }
}

class _TextSelectionDelegate
    extends TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey;

  _TextSelectionDelegate(this.editableTextKey);

  @override
  bool get forcePressEnabled => true;

  @override
  bool get selectionEnabled => true;
}
