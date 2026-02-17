import 'dart:typed_data';

/// The source of an image insertion request.
enum ImageInsertSource {
  /// Image was dropped onto the editor via drag-and-drop.
  dragDrop,

  /// Image was pasted from the clipboard.
  paste,

  /// Image was selected via a file picker.
  filePicker,

  /// Image insertion was triggered from the toolbar button.
  toolbar,
}

/// Event data passed to the [MarkdownEditor.onImageInsert] callback.
///
/// Contains information about how and what image the user wants to insert.
/// The callback should return the URL to use in the markdown image syntax,
/// or `null` to cancel the insertion.
class ImageInsertEvent {
  /// How the image insertion was triggered.
  final ImageInsertSource source;

  /// Raw image bytes (available for drag-drop and paste sources).
  final Uint8List? bytes;

  /// File path (available for file picker source).
  final String? filePath;

  /// MIME type of the image, if known.
  final String? mimeType;

  const ImageInsertEvent({
    required this.source,
    this.bytes,
    this.filePath,
    this.mimeType,
  });
}
