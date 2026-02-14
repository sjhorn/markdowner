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
      manager.setInitialState('', sel0);
      manager.recordChange('Hello', sel5);
      expect(manager.canUndo, isFalse); // Not committed yet (pending)

      manager.breakGroup();
      expect(manager.canUndo, isTrue);
      expect(manager.undoStackSize, equals(1));
    });

    test('multiple records before breakGroup coalesce into one', () {
      manager.setInitialState('', sel0);
      manager.recordChange('H', sel0);
      manager.recordChange('He', sel0);
      manager.recordChange('Hel', sel0);
      manager.breakGroup();

      // Only one undo entry (the initial state before the edit group)
      expect(manager.undoStackSize, equals(1));
      final snapshot = manager.undo('Hel', sel0);
      expect(snapshot!.markdown, equals(''));
    });

    test('breakGroup with no pending does nothing', () {
      manager.breakGroup();
      expect(manager.canUndo, isFalse);
    });

    test('coalesce timer auto-commits after duration', () async {
      manager.setInitialState('', sel0);
      manager.recordChange('Hello', sel5);
      expect(manager.canUndo, isFalse);

      // Wait for coalesce timer
      await Future.delayed(const Duration(seconds: 2));

      expect(manager.canUndo, isTrue);
    });
  });

  group('undo', () {
    test('returns previous snapshot', () {
      manager.setInitialState('Initial', sel0);
      manager.recordChange('Hello', sel5);
      manager.breakGroup();

      final snapshot = manager.undo('Hello', sel5);
      expect(snapshot, isNotNull);
      expect(snapshot!.markdown, equals('Initial'));
      expect(snapshot.selection, equals(sel0));
    });

    test('pushes current state to redo stack', () {
      manager.setInitialState('Initial', sel0);
      manager.recordChange('Hello', sel5);
      manager.breakGroup();

      manager.undo('Hello', sel5);
      expect(manager.canRedo, isTrue);
    });

    test('multiple undos traverse stack', () {
      manager.setInitialState('v0', sel0);
      manager.recordChange('A', sel0);
      manager.breakGroup();
      manager.recordChange('B', sel5);
      manager.breakGroup();

      final snap1 = manager.undo('B', sel5);
      expect(snap1!.markdown, equals('A'));

      final snap2 = manager.undo('A', sel0);
      expect(snap2!.markdown, equals('v0'));

      expect(manager.canUndo, isFalse);
    });

    test('commits pending before undoing', () {
      manager.setInitialState('v0', sel0);
      manager.recordChange('A', sel0);
      manager.breakGroup();
      manager.recordChange('B', sel5);
      // B is still pending, not committed

      final snap = manager.undo('B', sel5);
      // Should commit B first, then undo returns the state before B
      expect(snap!.markdown, equals('A'));
    });
  });

  group('redo', () {
    test('returns next snapshot after undo', () {
      manager.setInitialState('Initial', sel0);
      manager.recordChange('Hello', sel5);
      manager.breakGroup();

      manager.undo('Hello', sel5);
      final snapshot = manager.redo('Initial', sel0);
      expect(snapshot, isNotNull);
      expect(snapshot!.markdown, equals('Hello'));
    });

    test('redo pushes current state to undo stack', () {
      manager.setInitialState('Initial', sel0);
      manager.recordChange('A', sel0);
      manager.breakGroup();

      manager.undo('A', sel0);
      manager.redo('Initial', sel0);
      expect(manager.canUndo, isTrue);
    });

    test('new change clears redo stack', () {
      manager.setInitialState('Initial', sel0);
      manager.recordChange('A', sel0);
      manager.breakGroup();

      manager.undo('A', sel0);
      expect(manager.canRedo, isTrue);

      manager.recordChange('C', sel10);
      expect(manager.canRedo, isFalse);
    });
  });

  group('real-world undo/redo scenario', () {
    test('undo restores text to before the edit', () {
      // Simulate real editor flow: initial text, then user types
      manager.setInitialState('initial', sel0);

      // User types, controller fires recordChange with NEW text
      manager.recordChange('initial hello', sel5);
      manager.breakGroup();

      // Undo should restore to 'initial', not 'initial hello'
      final result = manager.undo('initial hello', sel5);
      expect(result, isNotNull);
      expect(result!.markdown, equals('initial'));
    });

    test('redo restores text after undo', () {
      manager.setInitialState('initial', sel0);

      manager.recordChange('modified', sel5);
      manager.breakGroup();

      // Undo back to 'initial'
      final undoResult = manager.undo('modified', sel5);
      expect(undoResult!.markdown, equals('initial'));

      // Redo should restore 'modified'
      final redoResult = manager.redo('initial', sel0);
      expect(redoResult, isNotNull);
      expect(redoResult!.markdown, equals('modified'));
    });

    test('multiple edits then undo walks backward through states', () {
      manager.setInitialState('v0', sel0);

      manager.recordChange('v1', sel0);
      manager.breakGroup();
      manager.recordChange('v2', sel5);
      manager.breakGroup();

      // First undo: v2 → v1
      final snap1 = manager.undo('v2', sel5);
      expect(snap1!.markdown, equals('v1'));

      // Second undo: v1 → v0
      final snap2 = manager.undo('v1', sel0);
      expect(snap2!.markdown, equals('v0'));

      // No more undo
      expect(manager.undo('v0', sel0), isNull);
    });

    test('undo then redo round-trips correctly', () {
      manager.setInitialState('v0', sel0);

      manager.recordChange('v1', sel0);
      manager.breakGroup();
      manager.recordChange('v2', sel5);
      manager.breakGroup();

      // Undo twice: v2 → v1 → v0
      manager.undo('v2', sel5);
      manager.undo('v1', sel0);

      // Redo twice: v0 → v1 → v2
      final redo1 = manager.redo('v0', sel0);
      expect(redo1!.markdown, equals('v1'));
      final redo2 = manager.redo('v1', sel0);
      expect(redo2!.markdown, equals('v2'));
    });

    test('typing after undo clears redo stack', () {
      manager.setInitialState('v0', sel0);

      manager.recordChange('v1', sel0);
      manager.breakGroup();

      // Undo back to v0
      manager.undo('v1', sel0);
      expect(manager.canRedo, isTrue);

      // User types new text — redo should be cleared
      manager.recordChange('v1-alt', sel5);
      expect(manager.canRedo, isFalse);
    });
  });

  group('max stack size', () {
    test('trims undo stack when over max', () {
      manager.setInitialState('state_init', sel0);
      for (var i = 0; i < 250; i++) {
        manager.recordChange('state_$i', sel0);
        manager.breakGroup();
      }
      expect(manager.undoStackSize, equals(UndoRedoManager.maxStackSize));
    });
  });

  group('snapshot naming', () {
    test('setInitialState creates snapshot named "Initial"', () {
      manager.setInitialState('hello', sel0);
      // After one edit + undo, the initial snapshot should have name "Initial"
      manager.recordChange('hello world', sel5);
      manager.breakGroup();
      final snapshot = manager.undo('hello world', sel5);
      expect(snapshot!.name, equals('Initial'));
    });

    test('typing text generates "Typed ..." name', () {
      manager.setInitialState('', sel0);
      manager.recordChange('Hello', sel5);
      manager.breakGroup();
      // The committed state (lastCommittedState) should be named for the typing
      // We can see this by doing another edit, then undoing to get back to it
      manager.recordChange('Hello World', sel10);
      manager.breakGroup();
      final snapshot = manager.undo('Hello World', sel10);
      expect(snapshot!.name, startsWith("Typed '"));
    });

    test('deleting text generates "Deleted N chars" name', () {
      manager.setInitialState('Hello World', sel10);
      manager.recordChange('Hello', sel5);
      manager.breakGroup();
      manager.recordChange('Hello!', sel5);
      manager.breakGroup();
      final snapshot = manager.undo('Hello!', sel5);
      expect(snapshot!.name, equals('Deleted 6 chars'));
    });

    test('same-length edit generates "Edited text" name', () {
      manager.setInitialState('Hello', sel5);
      manager.recordChange('Hallo', sel5);
      manager.breakGroup();
      manager.recordChange('Hallo!', sel5);
      manager.breakGroup();
      final snapshot = manager.undo('Hallo!', sel5);
      expect(snapshot!.name, equals('Edited text'));
    });

    test('undoNames returns names most-recent-first', () {
      manager.setInitialState('', sel0);
      manager.recordChange('Hello', sel5);
      manager.breakGroup();
      manager.recordChange('Hello World', sel10);
      manager.breakGroup();

      final names = manager.undoNames;
      expect(names.length, equals(2));
      // Most recent first: the "Typed 'Hello'" snapshot, then "Initial"
      expect(names[0], startsWith("Typed '"));
      expect(names[1], equals('Initial'));
    });

    test('redoNames returns names most-recent-first after undo', () {
      manager.setInitialState('', sel0);
      manager.recordChange('A', sel0);
      manager.breakGroup();
      manager.recordChange('AB', sel5);
      manager.breakGroup();

      manager.undo('AB', sel5);
      manager.undo('A', sel0);

      final names = manager.redoNames;
      expect(names.length, equals(2));
      // Most recent redo first
      expect(names[0], startsWith("Typed '"));
      expect(names[1], startsWith("Typed '"));
    });

    test('undoSteps(2) jumps back 2 steps', () {
      manager.setInitialState('v0', sel0);
      manager.recordChange('v1', sel0);
      manager.breakGroup();
      manager.recordChange('v2', sel5);
      manager.breakGroup();

      final snapshot = manager.undoSteps(2, 'v2', sel5);
      expect(snapshot, isNotNull);
      expect(snapshot!.markdown, equals('v0'));
    });

    test('redoSteps(2) jumps forward 2 steps', () {
      manager.setInitialState('v0', sel0);
      manager.recordChange('v1', sel0);
      manager.breakGroup();
      manager.recordChange('v2', sel5);
      manager.breakGroup();

      // Undo 2 steps
      manager.undoSteps(2, 'v2', sel5);

      // Redo 2 steps
      final snapshot = manager.redoSteps(2, 'v0', sel0);
      expect(snapshot, isNotNull);
      expect(snapshot!.markdown, equals('v2'));
    });

    test('undoSteps with count exceeding stack size undoes all available', () {
      manager.setInitialState('v0', sel0);
      manager.recordChange('v1', sel0);
      manager.breakGroup();

      final snapshot = manager.undoSteps(5, 'v1', sel0);
      expect(snapshot, isNotNull);
      expect(snapshot!.markdown, equals('v0'));
    });

    test('undoSteps(0) returns null', () {
      manager.setInitialState('v0', sel0);
      manager.recordChange('v1', sel0);
      manager.breakGroup();

      expect(manager.undoSteps(0, 'v1', sel0), isNull);
    });

    test('redoSteps(0) returns null', () {
      manager.setInitialState('v0', sel0);
      manager.recordChange('v1', sel0);
      manager.breakGroup();
      manager.undo('v1', sel0);

      expect(manager.redoSteps(0, 'v0', sel0), isNull);
    });

    test('typed name truncates long text to ~12 chars', () {
      manager.setInitialState('', sel0);
      manager.recordChange('This is a very long string that should be truncated', sel5);
      manager.breakGroup();
      manager.recordChange('This is a very long string that should be truncated!', sel5);
      manager.breakGroup();

      final names = manager.undoNames;
      // The first entry (most recent) should have a truncated typed name
      expect(names[0].length, lessThan(30));
      expect(names[0], contains('...'));
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
