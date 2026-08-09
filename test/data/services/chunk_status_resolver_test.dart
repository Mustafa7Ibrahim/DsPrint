import 'package:ds_print/src/data/services/chunk_status_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ChunkStatusResolver();

  group('ChunkStatusResolver.resolve', () {
    test('total 1 -> [oneIndex]', () {
      expect(resolver.resolve(index: 0, total: 1), ChunkStatus.oneIndex);
    });

    test('total 2 -> [start, completed]', () {
      expect(resolver.resolve(index: 0, total: 2), ChunkStatus.start);
      expect(resolver.resolve(index: 1, total: 2), ChunkStatus.completed);
    });

    test('total 3 -> [start, progress, completed]', () {
      expect(resolver.resolve(index: 0, total: 3), ChunkStatus.start);
      expect(resolver.resolve(index: 1, total: 3), ChunkStatus.progress);
      expect(resolver.resolve(index: 2, total: 3), ChunkStatus.completed);
    });

    test('total 5 -> [start, progress, progress, progress, completed]', () {
      final statuses = List.generate(
        5,
        (i) => resolver.resolve(index: i, total: 5),
      );
      expect(statuses, [
        ChunkStatus.start,
        ChunkStatus.progress,
        ChunkStatus.progress,
        ChunkStatus.progress,
        ChunkStatus.completed,
      ]);
    });
  });

  group('ChunkStatus.wireName', () {
    // The Kotlin side matches these literally (including the hyphen in
    // "one-index") - a rename here is a silent native mismatch, not a
    // compile error.
    test('wire strings match the native contract exactly', () {
      expect(ChunkStatus.start.wireName, 'start');
      expect(ChunkStatus.progress.wireName, 'progress');
      expect(ChunkStatus.completed.wireName, 'completed');
      expect(ChunkStatus.oneIndex.wireName, 'one-index');
    });
  });
}
