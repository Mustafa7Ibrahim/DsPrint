/// Per-chunk status sent alongside each piece of a split payload. Wire names
/// (esp. the `one-index` hyphen) match the Kotlin side's literal string match.
enum ChunkStatus {
  start,
  progress,
  completed,
  oneIndex;

  String get wireName => switch (this) {
        ChunkStatus.start => 'start',
        ChunkStatus.progress => 'progress',
        ChunkStatus.completed => 'completed',
        ChunkStatus.oneIndex => 'one-index',
      };
}

/// Rules ported verbatim from the legacy `_loopDataSplit`: a chunk that is
/// both first and last is `oneIndex`, not `start`.
class ChunkStatusResolver {
  const ChunkStatusResolver();

  ChunkStatus resolve({required int index, required int total}) {
    final isFirst = index == 0;
    final isLast = index == total - 1;
    if (isFirst && isLast) return ChunkStatus.oneIndex;
    if (isFirst) return ChunkStatus.start;
    if (isLast) return ChunkStatus.completed;
    return ChunkStatus.progress;
  }
}
