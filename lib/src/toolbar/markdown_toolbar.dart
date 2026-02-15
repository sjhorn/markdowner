import 'package:flutter/material.dart';

import '../editor/markdown_editing_controller.dart';
import '../widgets/markdown_editor.dart';

/// Inline format types that can be active at a cursor position.
enum InlineFormatType { bold, italic, inlineCode, strikethrough, link }

/// Block types for determining the active block at cursor position.
enum BlockType {
  paragraph,
  heading,
  unorderedList,
  orderedList,
  blockquote,
  codeBlock,
  thematicBreak,
  table,
  blank,
}

/// Items available in the default markdown toolbar.
enum MarkdownToolbarItem {
  bold,
  italic,
  inlineCode,
  strikethrough,
  heading,
  link,
  codeBlock,
  indent,
  outdent,
  undo,
  redo,
}

/// A configurable toolbar widget for the markdown editor.
///
/// Renders a row of formatting buttons that interact with a
/// [MarkdownEditingController] via a [MarkdownEditorState].
/// Buttons reflect the current cursor context (e.g., bold button
/// highlights when cursor is inside bold text).
class MarkdownToolbar extends StatelessWidget {
  /// The controller to read active format state from.
  final MarkdownEditingController controller;

  /// Key to the [MarkdownEditorState] for performing toolbar actions.
  final GlobalKey<MarkdownEditorState> editorKey;

  /// Which toolbar items to show. Defaults to all items.
  final List<MarkdownToolbarItem>? items;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    required this.editorKey,
    this.items,
  });

  static const _defaultItems = [
    MarkdownToolbarItem.bold,
    MarkdownToolbarItem.italic,
    MarkdownToolbarItem.inlineCode,
    MarkdownToolbarItem.strikethrough,
    MarkdownToolbarItem.heading,
    MarkdownToolbarItem.link,
    MarkdownToolbarItem.codeBlock,
    MarkdownToolbarItem.indent,
    MarkdownToolbarItem.outdent,
    MarkdownToolbarItem.undo,
    MarkdownToolbarItem.redo,
  ];

  void _performAction(void Function(MarkdownEditorState s) action) {
    editorKey.currentState?.performToolbarAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = items ?? _defaultItems;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final inlineFormats = controller.activeInlineFormats;
        final blockType = controller.activeBlockType;
        final headingLevel = controller.activeHeadingLevel;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildButtons(
              context,
              visibleItems,
              inlineFormats,
              blockType,
              headingLevel,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildButtons(
    BuildContext context,
    List<MarkdownToolbarItem> visibleItems,
    Set<InlineFormatType> inlineFormats,
    BlockType blockType,
    int headingLevel,
  ) {
    final widgets = <Widget>[];
    MarkdownToolbarItem? prevItem;

    for (final item in visibleItems) {
      // Add divider between logical groups.
      if (prevItem != null && _shouldAddDivider(prevItem, item)) {
        widgets.add(const SizedBox(
          height: 24,
          child: VerticalDivider(width: 1),
        ));
      }

      switch (item) {
        case MarkdownToolbarItem.bold:
          widgets.add(_ToolbarButton(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            isActive: inlineFormats.contains(InlineFormatType.bold),
            onPressed: () => _performAction((s) => s.toggleBold()),
          ));
        case MarkdownToolbarItem.italic:
          widgets.add(_ToolbarButton(
            icon: Icons.format_italic,
            tooltip: 'Italic',
            isActive: inlineFormats.contains(InlineFormatType.italic),
            onPressed: () => _performAction((s) => s.toggleItalic()),
          ));
        case MarkdownToolbarItem.inlineCode:
          widgets.add(_ToolbarButton(
            icon: Icons.code,
            tooltip: 'Inline code',
            isActive: inlineFormats.contains(InlineFormatType.inlineCode),
            onPressed: () => _performAction((s) => s.toggleInlineCode()),
          ));
        case MarkdownToolbarItem.strikethrough:
          widgets.add(_ToolbarButton(
            icon: Icons.strikethrough_s,
            tooltip: 'Strikethrough',
            isActive:
                inlineFormats.contains(InlineFormatType.strikethrough),
            onPressed: () =>
                _performAction((s) => s.toggleStrikethrough()),
          ));
        case MarkdownToolbarItem.heading:
          widgets.add(_HeadingDropdown(
            activeLevel: headingLevel,
            onSelected: (level) =>
                _performAction((s) => s.setHeadingLevel(level)),
          ));
        case MarkdownToolbarItem.link:
          widgets.add(_ToolbarButton(
            icon: Icons.link,
            tooltip: 'Insert link',
            isActive: inlineFormats.contains(InlineFormatType.link),
            onPressed: () => _performAction((s) => s.insertLink()),
          ));
        case MarkdownToolbarItem.codeBlock:
          widgets.add(_ToolbarButton(
            icon: Icons.integration_instructions,
            tooltip: 'Toggle code block',
            isActive: blockType == BlockType.codeBlock,
            onPressed: () => _performAction((s) => s.toggleCodeBlock()),
          ));
        case MarkdownToolbarItem.indent:
          widgets.add(_ToolbarButton(
            icon: Icons.format_indent_increase,
            tooltip: 'Indent',
            onPressed: () => _performAction((s) => s.indent()),
          ));
        case MarkdownToolbarItem.outdent:
          widgets.add(_ToolbarButton(
            icon: Icons.format_indent_decrease,
            tooltip: 'Outdent',
            onPressed: () => _performAction((s) => s.outdent()),
          ));
        case MarkdownToolbarItem.undo:
          widgets.add(_UndoRedoButton(
            icon: Icons.undo,
            tooltip: 'Undo',
            onPressed: () => _performAction((s) => s.undo()),
            historyNames: editorKey.currentState?.undoNames ?? [],
            onHistorySelected: (index) =>
                _performAction((s) => s.undoSteps(index + 1)),
          ));
        case MarkdownToolbarItem.redo:
          widgets.add(_UndoRedoButton(
            icon: Icons.redo,
            tooltip: 'Redo',
            onPressed: () => _performAction((s) => s.redo()),
            historyNames: editorKey.currentState?.redoNames ?? [],
            onHistorySelected: (index) =>
                _performAction((s) => s.redoSteps(index + 1)),
          ));
      }

      prevItem = item;
    }

    return widgets;
  }

  bool _shouldAddDivider(MarkdownToolbarItem prev, MarkdownToolbarItem next) {
    const groups = [
      {
        MarkdownToolbarItem.bold,
        MarkdownToolbarItem.italic,
        MarkdownToolbarItem.inlineCode,
        MarkdownToolbarItem.strikethrough,
      },
      {MarkdownToolbarItem.heading},
      {MarkdownToolbarItem.link, MarkdownToolbarItem.codeBlock},
      {MarkdownToolbarItem.indent, MarkdownToolbarItem.outdent},
      {MarkdownToolbarItem.undo, MarkdownToolbarItem.redo},
    ];

    for (final group in groups) {
      if (group.contains(prev) && group.contains(next)) return false;
    }
    return true;
  }
}

/// A single toolbar icon button with active state highlight.
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.isActive = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;

    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      isSelected: isActive,
      color: isActive ? activeColor : null,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

/// Heading level dropdown button.
class _HeadingDropdown extends StatelessWidget {
  final int activeLevel;
  final ValueChanged<int> onSelected;

  const _HeadingDropdown({
    required this.activeLevel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = activeLevel > 0;

    return PopupMenuButton<int>(
      icon: Icon(
        Icons.title,
        color: isActive ? theme.colorScheme.primary : null,
      ),
      tooltip: 'Heading level',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (var i = 1; i <= 6; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                if (i == activeLevel)
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text('H$i'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: 0,
          child: Row(
            children: [
              if (activeLevel == 0)
                Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              const Text('Normal'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Undo/Redo button with history dropdown.
class _UndoRedoButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final List<String> historyNames;
  final ValueChanged<int> onHistorySelected;

  const _UndoRedoButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.historyNames,
    required this.onHistorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        PopupMenuButton<int>(
          tooltip: '$tooltip history',
          onSelected: onHistorySelected,
          itemBuilder: (context) {
            if (historyNames.isEmpty) {
              return [
                const PopupMenuItem<int>(
                  enabled: false,
                  child: Text('No history'),
                ),
              ];
            }
            return [
              for (var i = 0; i < historyNames.length; i++)
                PopupMenuItem<int>(
                  value: i,
                  child: Text(historyNames[i]),
                ),
            ];
          },
          padding: EdgeInsets.zero,
          child: const Icon(Icons.arrow_drop_down, size: 18),
        ),
      ],
    );
  }
}
