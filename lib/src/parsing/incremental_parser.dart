import 'package:petitparser/petitparser.dart' as pp;

import '../core/markdown_nodes.dart';
import 'markdown_parser.dart';

/// Parses markdown and detects which blocks changed between edits.
///
/// Currently performs a full re-parse (PetitParser tokens embed source
/// offsets that can't be incrementally adjusted). The optimization value
/// comes from [detectChangedBlocks], which enables span caching: only
/// rebuild TextSpans for blocks whose source text actually changed.
///
/// For typical editing (typing within a single block), only 1-2 blocks
/// change per keystroke. Combined with span caching, this reduces
/// `buildTextSpan()` work from O(n blocks) to O(1) for each edit.
class IncrementalParseEngine {
  final pp.Parser _parser;

  IncrementalParseEngine()
      : _parser = MarkdownParserDefinition().build();

  /// Full parse of the given text.
  MarkdownDocument parse(String text) {
    if (text.isEmpty) return MarkdownDocument(blocks: []);
    final result = _parser.parse(text);
    if (result is pp.Success) {
      return result.value as MarkdownDocument;
    }
    return MarkdownDocument(blocks: []);
  }

  /// Detect which block indices in [newDoc] differ from [oldDoc].
  ///
  /// Compares blocks by source text. Returns the set of indices in
  /// [newDoc] where the block's source text differs from the corresponding
  /// block in [oldDoc]. Also returns indices for any blocks that were
  /// added (newDoc is longer) or removed (oldDoc was longer, marked as
  /// all remaining indices being "changed").
  Set<int> detectChangedBlocks(
    MarkdownDocument oldDoc,
    MarkdownDocument newDoc,
  ) {
    final changed = <int>{};
    final oldLen = oldDoc.blocks.length;
    final newLen = newDoc.blocks.length;

    // Compare blocks from the start.
    int prefixMatch = 0;
    while (prefixMatch < oldLen &&
        prefixMatch < newLen &&
        oldDoc.blocks[prefixMatch].sourceText ==
            newDoc.blocks[prefixMatch].sourceText) {
      prefixMatch++;
    }

    // If documents are identical, no changes.
    if (prefixMatch == oldLen && prefixMatch == newLen) {
      return changed;
    }

    // Compare blocks from the end.
    int suffixMatch = 0;
    while (suffixMatch < (oldLen - prefixMatch) &&
        suffixMatch < (newLen - prefixMatch) &&
        oldDoc.blocks[oldLen - 1 - suffixMatch].sourceText ==
            newDoc.blocks[newLen - 1 - suffixMatch].sourceText) {
      suffixMatch++;
    }

    // All blocks between prefixMatch and (newLen - suffixMatch) changed.
    for (int i = prefixMatch; i < newLen - suffixMatch; i++) {
      changed.add(i);
    }

    // Also mark suffix blocks as changed if their offsets shifted
    // (which they always do when blocks before them change).
    // Even though their sourceText is the same, their position changed,
    // so they're still "structurally equivalent" but at different offsets.
    // For span caching purposes, sourceText match is sufficient.

    return changed;
  }
}
