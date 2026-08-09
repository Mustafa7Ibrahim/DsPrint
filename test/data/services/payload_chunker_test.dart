import 'package:ds_print/src/data/services/payload_chunker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_payloads.dart';

void main() {
  group('PayloadChunker.split', () {
    test(
        'exact multiple of chunk size gives correct count, no empty trailing chunk',
        () {
      const chunker = PayloadChunker(chunkSize: 10);
      final chunks = chunker.split(''.padRight(30, 'a'));
      expect(chunks.length, 3);
      expect(chunks.every((c) => c.length == 10), isTrue);
      expect(chunks.any((c) => c.isEmpty), isFalse);
    });

    test('non-multiple leaves the remainder in the last chunk', () {
      const chunker = PayloadChunker(chunkSize: 10);
      final chunks = chunker.split(''.padRight(25, 'a'));
      expect(chunks.length, 3);
      expect(chunks[0].length, 10);
      expect(chunks[1].length, 10);
      expect(chunks[2].length, 5);
    });

    test('input shorter than the chunk size produces a single chunk', () {
      const chunker = PayloadChunker(chunkSize: 1000);
      final chunks = chunker.split('short');
      expect(chunks, ['short']);
    });

    test('empty input returns const [] rather than [""]', () {
      const chunker = PayloadChunker();
      final chunks = chunker.split('');
      expect(chunks, const <String>[]);
      expect(chunks, isNot(equals(<String>[''])));
    });

    test(
        'losslessness: split(s).join() == s for several sizes, including 2.5 MB',
        () {
      const chunker = PayloadChunker();
      final inputs = <String>[
        'x',
        ''.padRight(999, 'a'),
        ''.padRight(1000, 'a'),
        ''.padRight(1001, 'a'),
        twoPointFiveMbPayload,
      ];
      for (final input in inputs) {
        expect(
          chunker.split(input).join(),
          input,
          reason: 'lost data round-tripping a ${input.length}-char payload',
        );
      }
    });

    test('custom chunkSize is honoured', () {
      const chunker = PayloadChunker(chunkSize: 3);
      expect(chunker.split('abcdefg'), ['abc', 'def', 'g']);
    });
  });
}
