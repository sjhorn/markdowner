import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../core/image_insert_event.dart';
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

  /// Called when the user triggers a save action (Cmd+S).
  final ValueChanged<String>? onSaved;

  /// Optional builder for a toolbar widget rendered above the editor.
  ///
  /// The builder receives the controller and editor key so toolbar buttons
  /// can read active state and perform formatting actions.
  final Widget Function(
    BuildContext context,
    MarkdownEditingController controller,
    GlobalKey<MarkdownEditorState> editorKey,
  )? toolbarBuilder;

  /// Focus node. If not provided, the widget creates and manages its own.
  final FocusNode? focusNode;

  /// Theme for the editor. Falls back to [MarkdownEditorTheme.light()].
  final MarkdownEditorTheme? theme;

  /// Callback when the user requests to insert an image.
  ///
  /// The callback receives an [ImageInsertEvent] describing how the insertion
  /// was triggered and should return the URL to use in the markdown, or `null`
  /// to cancel. When provided, the toolbar image button will invoke this
  /// callback with [ImageInsertSource.toolbar], then call
  /// [MarkdownEditingController.insertImageMarkdown] with the returned URL.
  final Future<String?> Function(ImageInsertEvent)? onImageInsert;

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
    this.onSaved,
    this.toolbarBuilder,
    this.onImageInsert,
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

  // Focus save/restore for toolbar interactions.
  TextSelection? _savedSelection;
  bool _initialFocusApplied = false;
  VoidCallback? _restorationGuard;

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

  void toggleBold() {
    _controller.toggleBold();
    SemanticsService.announce('Bold toggled', TextDirection.ltr);
  }

  void toggleItalic() {
    _controller.toggleItalic();
    SemanticsService.announce('Italic toggled', TextDirection.ltr);
  }

  void toggleInlineCode() {
    _controller.toggleInlineCode();
    SemanticsService.announce('Inline code toggled', TextDirection.ltr);
  }

  void toggleStrikethrough() {
    _controller.toggleStrikethrough();
    SemanticsService.announce('Strikethrough toggled', TextDirection.ltr);
  }

  void toggleHighlight() {
    _controller.toggleHighlight();
    SemanticsService.announce('Highlight toggled', TextDirection.ltr);
  }

  void toggleSubscript() {
    _controller.toggleSubscript();
    SemanticsService.announce('Subscript toggled', TextDirection.ltr);
  }

  void toggleSuperscript() {
    _controller.toggleSuperscript();
    SemanticsService.announce('Superscript toggled', TextDirection.ltr);
  }

  void setHeadingLevel(int level) {
    _controller.setHeadingLevel(level);
    SemanticsService.announce(
      level > 0 ? 'Heading level $level' : 'Heading removed',
      TextDirection.ltr,
    );
  }

  void indent() => _controller.indent();
  void outdent() => _controller.outdent();
  void insertLink() => _controller.insertLink();
  void insertImage() {
    if (widget.onImageInsert != null) {
      _handleImageInsertCallback();
    } else {
      _controller.insertImage();
    }
  }

  Future<void> _handleImageInsertCallback() async {
    final event = const ImageInsertEvent(source: ImageInsertSource.toolbar);
    final url = await widget.onImageInsert!(event);
    if (url != null && mounted) {
      _controller.insertImageMarkdown('', url);
    }
  }

  void toggleCodeBlock() => _controller.toggleCodeBlock();
  void toggleMath() => _controller.toggleMath();
  void insertFootnote() => _controller.insertFootnote();

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
    _focusNode.onKeyEvent = _handleTabKeyEvent;

    _controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
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
      _focusNode.removeListener(_onFocusChanged);
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
      _focusNode.onKeyEvent = _handleTabKeyEvent;
      _focusNode.addListener(_onFocusChanged);
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

  // ---------------------------------------------------------------------------
  // Focus save/restore for toolbar interactions
  // ---------------------------------------------------------------------------

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Focus lost — save current selection.
      _savedSelection = _controller.selection;
    } else if (_initialFocusApplied && _savedSelection != null) {
      // Focus regained (not the initial gain) — restore saved selection.
      final selection = _savedSelection!;
      _savedSelection = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.selection = selection;
        _armRestorationGuard(selection);
      });
    } else {
      _initialFocusApplied = true;
    }
  }

  void _armRestorationGuard(TextSelection savedSelection) {
    _removeRestorationGuard();
    void guard() {
      final sel = _controller.selection;
      final isSelectAll = sel.baseOffset == 0 &&
          sel.extentOffset == _controller.text.length &&
          sel.extentOffset > 0;
      if (isSelectAll) {
        _controller.selection = savedSelection;
      }
      _removeRestorationGuard();
    }

    _restorationGuard = guard;
    _controller.addListener(guard);
  }

  void _removeRestorationGuard() {
    if (_restorationGuard != null) {
      _controller.removeListener(_restorationGuard!);
      _restorationGuard = null;
    }
  }

  /// Restore the saved selection to the controller.
  ///
  /// When the browser steals focus (e.g. toolbar click), the controller's
  /// selection may get disturbed. Call this before performing an action that
  /// depends on the cursor position.
  void restoreSelection() {
    if (_savedSelection != null) {
      _controller.selection = _savedSelection!;
    }
  }

  /// Request focus back to the editor after a toolbar action.
  ///
  /// Call this from toolbar button handlers after performing the action
  /// (e.g. toggleBold). It schedules a focus request via post-frame callback,
  /// which triggers the save/restore cycle.
  void requestEditorFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  /// Execute a toolbar action with proper focus management.
  ///
  /// Restores the saved selection before the action runs (so the action
  /// operates at the correct cursor position), then requests focus back.
  /// Usage:
  /// ```dart
  /// _editorKey.currentState?.performToolbarAction((s) => s.toggleBold());
  /// ```
  void performToolbarAction(void Function(MarkdownEditorState state) action) {
    restoreSelection();
    action(this);
    // Update saved selection to the post-action cursor position so the
    // focus restoration cycle doesn't overwrite it with the pre-action one.
    _savedSelection = _controller.selection;
    requestEditorFocus();
  }

  @override
  void dispose() {
    _removeRestorationGuard();
    _focusNode.removeListener(_onFocusChanged);
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
        SingleActivator(LogicalKeyboardKey.keyH,
            shift: true, meta: _isMacOS, control: !_isMacOS):
            const _ToggleHighlightIntent(),
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

        // Indent / Outdent (Tab/Shift+Tab handled in _handleKeyEvent)
        SingleActivator(LogicalKeyboardKey.bracketRight,
            shift: true, meta: _isMacOS, control: !_isMacOS):
            const _IndentIntent(),
        SingleActivator(LogicalKeyboardKey.bracketLeft,
            shift: true, meta: _isMacOS, control: !_isMacOS):
            const _OutdentIntent(),

        // Insert link
        SingleActivator(LogicalKeyboardKey.keyK,
            meta: _isMacOS, control: !_isMacOS): const _InsertLinkIntent(),

        // Toggle code block
        SingleActivator(LogicalKeyboardKey.keyC,
            shift: true, meta: _isMacOS, control: !_isMacOS):
            const _ToggleCodeBlockIntent(),

        // Toggle inline math
        SingleActivator(LogicalKeyboardKey.keyM,
            shift: true, meta: _isMacOS, control: !_isMacOS):
            const _ToggleMathIntent(),

        // Save
        SingleActivator(LogicalKeyboardKey.keyS,
            meta: _isMacOS, control: !_isMacOS): const _SaveIntent(),
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
        _ToggleHighlightIntent:
            CallbackAction<_ToggleHighlightIntent>(
                onInvoke: (_) => toggleHighlight()),
        _SetHeadingLevelIntent: CallbackAction<_SetHeadingLevelIntent>(
            onInvoke: (intent) => setHeadingLevel(intent.level)),
        _UndoIntent:
            CallbackAction<_UndoIntent>(onInvoke: (_) => undo()),
        _RedoIntent:
            CallbackAction<_RedoIntent>(onInvoke: (_) => redo()),
        _IndentIntent:
            CallbackAction<_IndentIntent>(onInvoke: (_) => indent()),
        _OutdentIntent:
            CallbackAction<_OutdentIntent>(onInvoke: (_) => outdent()),
        _InsertLinkIntent:
            CallbackAction<_InsertLinkIntent>(onInvoke: (_) => insertLink()),
        _ToggleCodeBlockIntent:
            CallbackAction<_ToggleCodeBlockIntent>(
                onInvoke: (_) => toggleCodeBlock()),
        _ToggleMathIntent:
            CallbackAction<_ToggleMathIntent>(
                onInvoke: (_) => toggleMath()),
        _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) =>
                widget.onSaved?.call(_controller.text)),
      };

  /// Build the context menu with standard + markdown formatting actions.
  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final buttonItems = editableTextState.contextMenuButtonItems;

    // Add markdown formatting items when text is selected.
    final hasSelection = !_controller.selection.isCollapsed;
    if (hasSelection) {
      buttonItems.addAll([
        ContextMenuButtonItem(
          label: 'Bold',
          onPressed: () {
            ContextMenuController.removeAny();
            toggleBold();
          },
        ),
        ContextMenuButtonItem(
          label: 'Italic',
          onPressed: () {
            ContextMenuController.removeAny();
            toggleItalic();
          },
        ),
        ContextMenuButtonItem(
          label: 'Code',
          onPressed: () {
            ContextMenuController.removeAny();
            toggleInlineCode();
          },
        ),
        ContextMenuButtonItem(
          label: 'Strikethrough',
          onPressed: () {
            ContextMenuController.removeAny();
            toggleStrikethrough();
          },
        ),
        ContextMenuButtonItem(
          label: 'Link',
          onPressed: () {
            ContextMenuController.removeAny();
            insertLink();
          },
        ),
      ]);
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  /// Intercept Tab/Shift+Tab key events.
  KeyEventResult _handleTabKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        outdent();
      } else {
        indent();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? MarkdownEditorTheme.light();
    Widget editor = Container(
      color: theme.backgroundColor,
      padding: widget.padding,
      child: Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: _actions,
          child: _gestureDetectorBuilder.buildGestureDetector(
            behavior: HitTestBehavior.translucent,
            child: CustomPaint(
              painter: _GapFreeSelectionPainter(
                controller: _controller,
                editableKey: _editableKey,
                selectionColor: theme.selectionColor,
              ),
              child: EditableText(
                key: _editableKey,
                rendererIgnoresPointer: true,
                controller: _controller,
                focusNode: _focusNode,
                style: theme.baseStyle,
                cursorColor: theme.cursorColor,
                selectionColor: const Color(0x00000000),
                backgroundCursorColor:
                    theme.cursorColor.withValues(alpha: 0.1),
                readOnly: widget.readOnly,
                autofocus: widget.autofocus,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                contextMenuBuilder: _buildContextMenu,
                inputFormatters: [
                  // Tab chars are handled by _handleTabKeyEvent; block
                  // any platform-injected \t from reaching the controller.
                  FilteringTextInputFormatter.deny(RegExp(r'\t')),
                  _SmartEditFormatter(_controller),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.toolbarBuilder != null) {
      final editorKey = widget.key as GlobalKey<MarkdownEditorState>;
      editor = Column(
        children: [
          widget.toolbarBuilder!(context, _controller, editorKey),
          Expanded(child: SingleChildScrollView(child: editor)),
        ],
      );
    }

    return Semantics(
      label: 'Markdown editor',
      textField: true,
      child: editor,
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
// Gap-free selection painter
// ---------------------------------------------------------------------------

/// Paints selection highlights with no vertical gaps between lines.
///
/// The built-in [EditableText] selection can leave visible gaps between lines
/// when [TextStyle.height] > 1.0. This painter reads the selection boxes from
/// the [RenderEditable], groups them by line, and extends each line's top/bottom
/// to meet adjacent lines at the midpoint of any gap.
class _GapFreeSelectionPainter extends CustomPainter {
  final TextEditingController controller;
  final GlobalKey<EditableTextState> editableKey;
  final Color selectionColor;

  _GapFreeSelectionPainter({
    required this.controller,
    required this.editableKey,
    required this.selectionColor,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final sel = controller.selection;
    if (!sel.isValid || sel.isCollapsed) return;

    final editable = editableKey.currentState?.renderEditable;
    if (editable == null) return;

    final boxes = editable.getBoxesForSelection(sel);
    if (boxes.isEmpty) return;

    // Group boxes into lines. Boxes on the same line share a similar vertical
    // centre. Merge each line's boxes into a single bounding rect.
    final lineRects = <Rect>[];
    for (final box in boxes) {
      final rect = Rect.fromLTRB(box.left, box.top, box.right, box.bottom);
      if (lineRects.isEmpty ||
          ((rect.top + rect.bottom) / 2 -
                      (lineRects.last.top + lineRects.last.bottom) / 2)
                  .abs() >
              1.0) {
        lineRects.add(rect);
      } else {
        lineRects[lineRects.length - 1] =
            lineRects.last.expandToInclude(rect);
      }
    }

    // Close vertical gaps between adjacent lines by meeting at the midpoint.
    for (var i = 0; i < lineRects.length - 1; i++) {
      final gap = lineRects[i + 1].top - lineRects[i].bottom;
      if (gap > 0) {
        final mid = lineRects[i].bottom + gap / 2;
        lineRects[i] = Rect.fromLTRB(
          lineRects[i].left,
          lineRects[i].top,
          lineRects[i].right,
          mid,
        );
        lineRects[i + 1] = Rect.fromLTRB(
          lineRects[i + 1].left,
          mid,
          lineRects[i + 1].right,
          lineRects[i + 1].bottom,
        );
      }
    }

    final paint = Paint()..color = selectionColor;
    for (final rect in lineRects) {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GapFreeSelectionPainter old) => true;
}

// ---------------------------------------------------------------------------
// Smart Edit Formatter
// ---------------------------------------------------------------------------

/// A [TextInputFormatter] that intercepts Enter, Backspace, and Tab to apply
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

    // Detect single character insertion.
    if (newLen == oldLen + 1) {
      final insertPos = newValue.selection.baseOffset - 1;
      if (insertPos >= 0 && insertPos < newLen) {
        // Detect Enter.
        if (newValue.text[insertPos] == '\n') {
          final result = _controller.applySmartEnter(oldValue, newValue);
          if (result != null) return result;
        }

        // Smart pair completion (backtick, bracket, **, ~~).
        if (!newValue.composing.isValid || newValue.composing.isCollapsed) {
          final result =
              _controller.applySmartPairCompletion(oldValue, newValue);
          if (result != null) return result;
        }
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

class _ToggleHighlightIntent extends Intent {
  const _ToggleHighlightIntent();
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

class _IndentIntent extends Intent {
  const _IndentIntent();
}

class _OutdentIntent extends Intent {
  const _OutdentIntent();
}

class _InsertLinkIntent extends Intent {
  const _InsertLinkIntent();
}

class _ToggleCodeBlockIntent extends Intent {
  const _ToggleCodeBlockIntent();
}

class _ToggleMathIntent extends Intent {
  const _ToggleMathIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}
