import 'package:ds_print/src/data/platform/ds_web_controller.dart';
import 'package:ds_print/src/data/services/capture_height_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-written fake that serves scripted `runJavaScriptReturningResult`
/// values from a FIFO queue and records every script it was asked to run.
/// Injecting a zero [CaptureHeightResolver.pollInterval] (rather than
/// pulling in `fake_async`) keeps these tests from actually waiting
/// 40 x 500ms while still exercising the real polling loop.
class FakeDsWebController implements DsWebController {
  FakeDsWebController(List<String> results) : _queue = List.of(results);

  final List<String> _queue;
  int _index = 0;

  final List<String> runJavaScriptCalls = [];
  final List<String> returningResultCalls = [];

  @override
  Future<void> loadUrl(String url,
      {Map<String, String> headers = const {}}) async {}

  @override
  Future<void> runJavaScript(String script) async {
    runJavaScriptCalls.add(script);
  }

  @override
  Future<String> runJavaScriptReturningResult(String script) async {
    returningResultCalls.add(script);
    if (_index >= _queue.length) {
      throw StateError(
        'FakeDsWebController: queue exhausted after $_index reads - the '
        'resolver polled more times than this test expected.',
      );
    }
    return _queue[_index++];
  }
}

void main() {
  group('CaptureHeightResolver.stabilize', () {
    test('returns once requiredStableReads consecutive reads differ by < 1.0',
        () async {
      final web = FakeDsWebController(['100', '100', '100']);
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);

      final result = await resolver.stabilize(100);

      expect(result, 100.0);
      expect(web.returningResultCalls.length, 3);
    });

    test(
        'a growing sequence resets the stable counter - does not settle at the old value',
        () async {
      final web =
          FakeDsWebController(['100', '100', '200', '200', '200', '200']);
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);

      final result = await resolver.stabilize(100);

      // Only two consecutive 100s occur (not enough for the default 3), then
      // the jump to 200 resets the counter; it must settle on 200, not 100.
      expect(result, 200.0);
      expect(web.returningResultCalls.length, 6);
    });

    test('gives up after maxPolls and returns the last value', () async {
      final web = FakeDsWebController(['200', '300', '400', '500', '600']);
      final resolver = CaptureHeightResolver(
        web: web,
        pollInterval: Duration.zero,
        maxPolls: 5,
      );

      final result = await resolver.stabilize(100);

      expect(result, 600.0);
      expect(web.returningResultCalls.length, 5);
    });

    test('onHeight is called on every poll', () async {
      final web = FakeDsWebController(['150', '150', '150']);
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);
      final heights = <double>[];

      await resolver.stabilize(150, onHeight: heights.add);

      expect(heights, [150.0, 150.0, 150.0]);
    });

    test('unparseable reads fall back to the previous value', () async {
      final web = FakeDsWebController(['not-a-number', '10', '10']);
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);
      final heights = <double>[];

      final result = await resolver.stabilize(10, onHeight: heights.add);

      // The unparseable first read must fall back to the initial value (10),
      // not propagate NaN.
      expect(heights, [10.0, 10.0, 10.0]);
      expect(result, 10.0);
    });
  });

  group('CaptureHeightResolver.trimToContentBottom', () {
    test('returns the parsed value', () async {
      final web = FakeDsWebController(['1234.5']);
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);

      expect(await resolver.trimToContentBottom(), 1234.5);
    });

    test('returns null when unparseable', () async {
      final web = FakeDsWebController(['not-a-number']);
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);

      expect(await resolver.trimToContentBottom(), isNull);
    });

    test('returns null when <= 0', () async {
      final zeroWeb = FakeDsWebController(['0']);
      final zeroResolver =
          CaptureHeightResolver(web: zeroWeb, pollInterval: Duration.zero);
      expect(await zeroResolver.trimToContentBottom(), isNull);

      final negativeWeb = FakeDsWebController(['-10']);
      final negativeResolver =
          CaptureHeightResolver(web: negativeWeb, pollInterval: Duration.zero);
      expect(await negativeResolver.trimToContentBottom(), isNull);
    });
  });

  test('minTrimDeltaPx is 5', () {
    expect(CaptureHeightResolver.minTrimDeltaPx, 5);
  });

  group('CaptureHeightResolver.resolvePixelRatio', () {
    test('clamps to [1.5, 10.0]', () {
      // Tiny area -> ratio would blow way past 10.0 unclamped.
      expect(
        CaptureHeightResolver.resolvePixelRatio(captureWidth: 10, height: 10),
        10.0,
      );
      // Huge area -> ratio would drop way below 1.5 unclamped.
      expect(
        CaptureHeightResolver.resolvePixelRatio(
            captureWidth: 100000, height: 100000),
        1.5,
      );
    });

    test(
        'captureWidth * height * ratio^2 stays close to ~8M for a mid-range input',
        () {
      const width = 500.0;
      const height = 1000.0;
      final ratio = CaptureHeightResolver.resolvePixelRatio(
          captureWidth: width, height: height);

      expect(ratio, greaterThanOrEqualTo(1.5));
      expect(ratio, lessThanOrEqualTo(10.0));
      expect(width * height * ratio * ratio, closeTo(8000000, 1));
    });

    test(
        'height <= 0 or captureWidth <= 0 returns 1.5 rather than NaN/Infinity',
        () {
      expect(
          CaptureHeightResolver.resolvePixelRatio(captureWidth: 100, height: 0),
          1.5);
      expect(
          CaptureHeightResolver.resolvePixelRatio(
              captureWidth: 100, height: -5),
          1.5);
      expect(
          CaptureHeightResolver.resolvePixelRatio(captureWidth: 0, height: 100),
          1.5);
      expect(
          CaptureHeightResolver.resolvePixelRatio(
              captureWidth: -5, height: 100),
          1.5);
    });
  });

  group('CaptureHeightResolver expand/restore', () {
    test(
        'restoreDocument sets exactly the same (element, property) pairs that expandDocument set',
        () async {
      final web = FakeDsWebController([]);
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);

      await resolver.expandDocument();
      await resolver.restoreDocument();

      expect(web.runJavaScriptCalls.length, 2);

      final pairPattern =
          RegExp(r'(document\.body|document\.documentElement)\.style\.(\w+)');
      Set<String> pairsIn(String script) => pairPattern
          .allMatches(script)
          .map((m) => '${m.group(1)}.${m.group(2)}')
          .toSet();

      final expandPairs = pairsIn(web.runJavaScriptCalls[0]);
      final restorePairs = pairsIn(web.runJavaScriptCalls[1]);

      expect(expandPairs, isNotEmpty);
      expect(
        restorePairs,
        equals(expandPairs),
        reason:
            'restoreDocument must leave the DOM exactly as expandDocument found it',
      );
    });
  });
}
