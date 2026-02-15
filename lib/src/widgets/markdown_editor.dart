import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // ---------------------------------------------------------------------------
  // Format toggle delegates
  // ---------------------------------------------------------------------------

  void toggleBold() => _controller.toggleBold();
  void toggleItalic() => _controller.toggleItalic();
  void toggleInlineCode() => _controller.toggleInlineCode();
  void toggleStrikethrough() => _controller.toggleStrikethrough();
  void setHeadingLevel(int level) => _controller.setHeadingLevel(level);

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

  static bool get _isMacOS =>
      defaultTargetPlatform == TargetPlatform.macOS;

  Map<ShortcutActivator, Intent> get _shortcuts => {
        // Inline formatting
        SingleActivator(LogicalKeyboardKey.keyB,
            meta: _isMacOS, control: !_isMacOS): const _ToggleBoldIntent(),
        SingleActivator(LogicalKeyboardKey.keyI,
            meta: _isMacOS, control: !_isMacOS): const _ToggleItalicIntent(),
        SingleActivator(LogicalKeyboardKey.keyK,
            shift: true, meta: _isMacOS, control: !_isMacOS):
            const _ToggleStrikethroughIntent(),
        SingleActivator(LogicalKeyboardKey.backquote,
            meta: _isMacOS, control: !_isMacOS):
            const _ToggleInlineCodeIntent(),

        // Headings
        SingleActivator(LogicalKeyboardKey.digit1,
            meta: _isMacOS, control: !_isMacOS):
            const _SetHeadingLevelIntent(1),
        SingleActivator(LogicalKeyboardKey.digit2,
            meta: _isMacOS, control: !_isMacOS):
            const _SetHeadingLevelIntent(2),
        SingleActivator(LogicalKeyboardKey.digit3,
            meta: _isMacOS, control: !_isMacOS):
            const _SetHeadingLevelIntent(3),
        SingleActivator(LogicalKeyboardKey.digit4,
            meta: _isMacOS, control: !_isMacOS):
            const _SetHeadingLevelIntent(4),
        SingleActivator(LogicalKeyboardKey.digit5,
            meta: _isMacOS, control: !_isMacOS):
            const _SetHeadingLevelIntent(5),
        SingleActivator(LogicalKeyboardKey.digit6,
            meta: _isMacOS, control: !_isMacOS):
            const _SetHeadingLevelIntent(6),
        SingleActivator(LogicalKeyboardKey.digit0,
            meta: _isMacOS, control: !_isMacOS):
            const _SetHeadingLevelIntent(0),

        // Undo / Redo
        SingleActivator(LogicalKeyboardKey.keyZ,
            meta: _isMacOS, control: !_isMacOS): const _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ,
            shift: true, meta: _isMacOS, control: !_isMacOS):
            const _RedoIntent(),
      };

  Map<Type, Action<Intent>> get _actions => {
        _ToggleBoldIntent: CallbackAction<_ToggleBoldIntent>(
            onInvoke: (_) => toggleBold()),
        _ToggleItalicIntent: CallbackAction<_ToggleItalicIntent>(
            onInvoke: (_) => toggleItalic()),
        _ToggleInlineCodeIntent: CallbackAction<_ToggleInlineCodeIntent>(
            onInvoke: (_) => toggleInlineCode()),
        _ToggleStrikethroughIntent:
            CallbackAction<_ToggleStrikethroughIntent>(
                onInvoke: (_) => toggleStrikethrough()),
        _SetHeadingLevelIntent: CallbackAction<_SetHeadingLevelIntent>(
            onInvoke: (intent) => setHeadingLevel(intent.level)),
        _UndoIntent:
            CallbackAction<_UndoIntent>(onInvoke: (_) => undo()),
        _RedoIntent:
            CallbackAction<_RedoIntent>(onInvoke: (_) => redo()),
      };

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? MarkdownEditorTheme.light();
    return Container(
      color: theme.backgroundColor,
      padding: widget.padding,
      child: Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: _actions,
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
              backgroundCursorColor:
                  theme.cursorColor.withValues(alpha: 0.1),
              readOnly: widget.readOnly,
              autofocus: widget.autofocus,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              inputFormatters: [_SmartEditFormatter(_controller)],
            ),
          ),
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

// ---------------------------------------------------------------------------
// Smart Edit Formatter
// ---------------------------------------------------------------------------

/// A [TextInputFormatter] that intercepts Enter and Backspace to apply
/// smart list/blockquote/heading behaviour via the controller.
class _SmartEditFormatter extends TextInputFormatter {
  final MarkdownEditingController _controller;

  _SmartEditFormatter(this._controller);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldLen = oldValue.text.length;
    final newLen = newValue.text.length;

    // Detect Enter: exactly one character added and it's a newline.
    if (newLen == oldLen + 1) {
      final insertPos = newValue.selection.baseOffset - 1;
      if (insertPos >= 0 &&
          insertPos < newLen &&
          newValue.text[insertPos] == '\n') {
        final result = _controller.applySmartEnter(oldValue, newValue);
        if (result != null) return result;
      }
    }

    // Detect Backspace: exactly one character removed.
    if (newLen == oldLen - 1 &&
        oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed) {
      final result = _controller.applySmartBackspace(oldValue, newValue);
      if (result != null) return result;
    }

    return newValue;
  }
}

// ---------------------------------------------------------------------------
// Intent classes for keyboard shortcuts
// ---------------------------------------------------------------------------

class _ToggleBoldIntent extends Intent {
  const _ToggleBoldIntent();
}

class _ToggleItalicIntent extends Intent {
  const _ToggleItalicIntent();
}

class _ToggleInlineCodeIntent extends Intent {
  const _ToggleInlineCodeIntent();
}

class _ToggleStrikethroughIntent extends Intent {
  const _ToggleStrikethroughIntent();
}

class _SetHeadingLevelIntent extends Intent {
  final int level;
  const _SetHeadingLevelIntent(this.level);
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}
