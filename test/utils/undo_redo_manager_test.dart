import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:markdowner/src/utils/undo_redo_manager.dart';

void main() {
  late UndoRedoManager manager;

  setUp(() {
    manager = UndoRedoManager();
  });

  tearDown(() {
    manager.dispose();
  });

  const sel0 = TextSelection.collapsed(offset: 0);
  const sel5 = TextSelection.collapsed(offset: 5);
  const sel10 = TextSelection.collapsed(offset: 10);

  group('initial state', () {
    test('canUndo is false', () {
      expect(manager.canUndo, isFalse);
    });

    test('canRedo is false', () {
      expect(manager.canRedo, isFalse);
    });

    test('undo returns null', () {
      expect(manager.undo('text', sel0), isNull);
    });

    test('redo returns null', () {
      expect(manager.redo('text', sel0), isNull);
    });
  });

  group('recordChange and breakGroup', () {
    test('breakGroup commits pending change to undo stack', () {
      manager.recordChange('Hello', sel5);
      expect(manager.canUndo, isFalse); // Not committed yet (pending)

      manager.breakGroup();
      expect(manager.canUndo, isTrue);
      expect(manager.undoStackSize, equals(1));
    });

    test('multiple records before breakGroup coalesce into one', () {
      manager.recordChange('H', sel0);
      manager.recordChange('He', sel0);
      manager.recordChange('Hel', sel0);
      manager.breakGroup();

      // Only the last pending snapshot is committed
      expect(manager.undoStackSize, equals(1));
      final snapshot = manager.undo('Hel', sel0);
      expect(snapshot!.markdown, equals('Hel'));
    });

    test('breakGroup with no pending does nothing', () {
      manager.breakGroup();
      expect(manager.canUndo, isFalse);
    });

    test('coalesce timer auto-commits after duration', () async {
      manager.recordChange('Hello', sel5);
      expect(manager.canUndo, isFalse);

      // Wait for coalesce timer
      await Future.delayed(const Duration(seconds: 2));

      expect(manager.canUndo, isTrue);
    });
  });

  group('undo', () {
    test('returns previous snapshot', () {
      manager.recordChange('Hello', sel5);
      manager.breakGroup();

      final snapshot = manager.undo('Hello World', sel10);
      expect(snapshot, isNotNull);
      expect(snapshot!.markdown, equals('Hello'));
      expect(snapshot.selection, equals(sel5));
    });

    test('pushes current state to redo stack', () {
      manager.recordChange('Hello', sel5);
      manager.breakGroup();

      manager.undo('Current', sel10);
      expect(manager.canRedo, isTrue);
    });

    test('multiple undos traverse stack', () {
      manager.recordChange('A', sel0);
      manager.breakGroup();
      manager.recordChange('B', sel5);
      manager.breakGroup();

      final snap1 = manager.undo('C', sel10);
      expect(snap1!.markdown, equals('B'));

      final snap2 = manager.undo('B', sel5);
      expect(snap2!.markdown, equals('A'));

      expect(manager.canUndo, isFalse);
    });

    test('commits pending before undoing', () {
      manager.recordChange('A', sel0);
      manager.breakGroup();
      manager.recordChange('B', sel5);
      // B is still pending, not committed

      final snap = manager.undo('B', sel5);
      // Should commit B first, then undo returns B
      expect(snap!.markdown, equals('B'));
    });
  });

  group('redo', () {
    test('returns next snapshot after undo', () {
      manager.recordChange('Hello', sel5);
      manager.breakGroup();

      manager.undo('Current', sel10);
      final snapshot = manager.redo('Hello', sel5);
      expect(snapshot, isNotNull);
      expect(snapshot!.markdown, equals('Current'));
    });

    test('redo pushes current state to undo stack', () {
      manager.recordChange('A', sel0);
      manager.breakGroup();

      manager.undo('B', sel5);
      manager.redo('A', sel0);
      expect(manager.canUndo, isTrue);
    });

    test('new change clears redo stack', () {
      manager.recordChange('A', sel0);
      manager.breakGroup();

      manager.undo('B', sel5);
      expect(manager.canRedo, isTrue);

      manager.recordChange('C', sel10);
      expect(manager.canRedo, isFalse);
    });
  });

  group('max stack size', () {
    test('trims undo stack when over max', () {
      for (var i = 0; i < 250; i++) {
        manager.recordChange('state_$i', sel0);
        manager.breakGroup();
      }
      expect(manager.undoStackSize, equals(UndoRedoManager.maxStackSize));
    });
  });

  group('dispose', () {
    test('cancels timer without error', () {
      manager.recordChange('Hello', sel5);
      // Should not throw
      manager.dispose();
    });

    test('dispose when no timer active', () {
      // Should not throw
      manager.dispose();
    });
  });
}
