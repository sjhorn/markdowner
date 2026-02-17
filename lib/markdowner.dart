/// Markdowner — a high-performance Flutter markdown WYSIWYG widget.
///
/// Phase 1 exports: AST model, parser, rendering, controller, and editor widget.
library;

export 'src/core/markdown_extension.dart';
export 'src/core/markdown_nodes.dart';
export 'src/editor/markdown_editing_controller.dart';
export 'src/parsing/markdown_grammar.dart';
export 'src/parsing/markdown_parser.dart';
export 'src/rendering/markdown_render_engine.dart';
export 'src/theme/markdown_editor_theme.dart';
export 'src/toolbar/markdown_toolbar.dart';
export 'src/utils/cursor_mapper.dart';
export 'src/utils/emoji_map.dart';
export 'src/utils/html_to_markdown.dart';
export 'src/utils/markdown_to_html.dart';
export 'src/utils/undo_redo_manager.dart';
export 'src/widgets/markdown_editor.dart';
