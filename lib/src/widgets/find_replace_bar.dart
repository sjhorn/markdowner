import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/find_replace_controller.dart';

/// A compact find and replace bar for the markdown editor.
///
/// Shows a search text field with match count, navigation buttons, and
/// optionally a replace row.
class FindReplaceBar extends StatefulWidget {
  /// The find/replace controller.
  final FindReplaceController findController;

  /// Whether to show the replace row.
  final bool showReplace;

  /// Called when the user modifies text via replace or replace-all.
  /// The callback receives the new text.
  final ValueChanged<String> onReplace;

  /// The current editor text to search within.
  final String text;

  /// Called when the user closes the bar.
  final VoidCallback onClose;

  const FindReplaceBar({
    super.key,
    required this.findController,
    required this.showReplace,
    required this.onReplace,
    required this.text,
    required this.onClose,
  });

  @override
  State<FindReplaceBar> createState() => _FindReplaceBarState();
}

class _FindReplaceBarState extends State<FindReplaceBar> {
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();
    _searchFocusNode.onKeyEvent = _handleKeyEvent;
    widget.findController.addListener(_onFindChanged);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    widget.findController.removeListener(_onFindChanged);
    _searchController.dispose();
    _replaceController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFindChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String query) {
    widget.findController.search(query, widget.text);
  }

  void _onReplaceCurrent() {
    final replacement = _replaceController.text;
    final newText =
        widget.findController.replaceCurrentMatch(widget.text, replacement);
    widget.onReplace(newText);
    // Re-search with updated text
    widget.findController.search(_searchController.text, newText);
  }

  void _onReplaceAll() {
    final replacement = _replaceController.text;
    final newText =
        widget.findController.replaceAll(widget.text, replacement);
    widget.onReplace(newText);
    widget.findController.search(_searchController.text, newText);
  }

  @override
  Widget build(BuildContext context) {
    final fc = widget.findController;
    final matchText = fc.matchCount > 0
        ? '${fc.currentMatchIndex + 1} of ${fc.matchCount}'
        : 'No matches';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    key: const Key('find_search_field'),
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Find',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                matchText,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const Key('find_prev_button'),
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                onPressed: fc.matchCount > 0 ? fc.previousMatch : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                tooltip: 'Previous match',
              ),
              IconButton(
                key: const Key('find_next_button'),
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                onPressed: fc.matchCount > 0 ? fc.nextMatch : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                tooltip: 'Next match',
              ),
              IconButton(
                key: const Key('find_close_button'),
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                tooltip: 'Close',
              ),
            ],
          ),
          // Replace row (optional)
          if (widget.showReplace) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      key: const Key('find_replace_field'),
                      controller: _replaceController,
                      decoration: const InputDecoration(
                        hintText: 'Replace',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('find_replace_button'),
                  onPressed: fc.matchCount > 0 ? _onReplaceCurrent : null,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                  ),
                  child: const Text('Replace', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  key: const Key('find_replace_all_button'),
                  onPressed: fc.matchCount > 0 ? _onReplaceAll : null,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                  ),
                  child: const Text('All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
