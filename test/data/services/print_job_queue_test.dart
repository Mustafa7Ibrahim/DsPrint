import 'package:ds_print/src/data/services/print_job_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrintJobQueue', () {
    test('two enqueued jobs run strictly sequentially', () async {
      final queue = PrintJobQueue();
      final events = <String>[];

      final jobA = queue.enqueue(() async {
        events.add('A-start');
        await Future<void>.delayed(const Duration(milliseconds: 30));
        events.add('A-end');
        return 'A';
      });
      final jobB = queue.enqueue(() async {
        events.add('B-start');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        events.add('B-end');
        return 'B';
      });

      final results = await Future.wait([jobA, jobB]);

      // Job B must not start before job A ends.
      expect(events, ['A-start', 'A-end', 'B-start', 'B-end']);
      expect(results, ['A', 'B']);
    });

    test('a throwing job does not wedge the queue - the next job still runs',
        () async {
      final queue = PrintJobQueue();
      final events = <String>[];

      final jobA = queue.enqueue<String>(() async {
        events.add('A');
        throw Exception('boom');
      });
      final jobB = queue.enqueue(() async {
        events.add('B');
        return 'B-result';
      });

      await expectLater(jobA, throwsException);
      expect(await jobB, 'B-result');
      expect(events, ['A', 'B']);
    });

    test("the throwing job's error propagates to its own caller", () async {
      final queue = PrintJobQueue();
      final error = Exception('specific-failure');

      final job = queue.enqueue<int>(() async => throw error);

      await expectLater(job, throwsA(same(error)));
    });

    test('results are returned to the right callers', () async {
      final queue = PrintJobQueue();

      final jobA = queue.enqueue(() async => 1);
      final jobB = queue.enqueue(() async => 2);
      final jobC = queue.enqueue(() async => 3);

      expect(await Future.wait([jobA, jobB, jobC]), [1, 2, 3]);
    });
  });
}
