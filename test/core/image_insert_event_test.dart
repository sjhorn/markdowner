import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdowner/src/core/image_insert_event.dart';

void main() {
  group('ImageInsertSource', () {
    test('has all 4 values', () {
      expect(ImageInsertSource.values, hasLength(4));
      expect(ImageInsertSource.values,
          contains(ImageInsertSource.dragDrop));
      expect(ImageInsertSource.values,
          contains(ImageInsertSource.paste));
      expect(ImageInsertSource.values,
          contains(ImageInsertSource.filePicker));
      expect(ImageInsertSource.values,
          contains(ImageInsertSource.toolbar));
    });
  });

  group('ImageInsertEvent', () {
    test('constructs with required source only', () {
      const event =
          ImageInsertEvent(source: ImageInsertSource.toolbar);

      expect(event.source, ImageInsertSource.toolbar);
      expect(event.bytes, isNull);
      expect(event.filePath, isNull);
      expect(event.mimeType, isNull);
    });

    test('constructs with all fields', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final event = ImageInsertEvent(
        source: ImageInsertSource.dragDrop,
        bytes: bytes,
        filePath: '/tmp/image.png',
        mimeType: 'image/png',
      );

      expect(event.source, ImageInsertSource.dragDrop);
      expect(event.bytes, bytes);
      expect(event.filePath, '/tmp/image.png');
      expect(event.mimeType, 'image/png');
    });

    test('constructs with paste source and bytes', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      final event = ImageInsertEvent(
        source: ImageInsertSource.paste,
        bytes: bytes,
        mimeType: 'image/jpeg',
      );

      expect(event.source, ImageInsertSource.paste);
      expect(event.bytes, isNotNull);
      expect(event.filePath, isNull);
      expect(event.mimeType, 'image/jpeg');
    });

    test('constructs with filePicker source and path', () {
      const event = ImageInsertEvent(
        source: ImageInsertSource.filePicker,
        filePath: '/Users/test/photo.jpg',
      );

      expect(event.source, ImageInsertSource.filePicker);
      expect(event.bytes, isNull);
      expect(event.filePath, '/Users/test/photo.jpg');
    });
  });
}
