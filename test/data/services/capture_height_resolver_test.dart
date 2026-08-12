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

    test('unparseable reads fall back to the previous value', () async {
      final web = FakeDsWebController(['not-a-number', '10', '10']);
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);

      final result = await resolver.stabilize(10);

      // The unparseable first read must fall back to the initial value (10),
      // not propagate NaN.
      expect(result, 10.0);
    });
  });

  group('CaptureHeightResolver.scrollTo', () {
    test('returns where the browser actually landed, not what was asked',
        () async {
      // The browser clamps at scrollHeight - viewportHeight, so the last page
      // of a document lands short. Reporting the request back would make the
      // caller skip the band between `actual` and `offset`.
      final web = FakeDsWebController(['1840']);
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);

      expect(await resolver.scrollTo(2000), 1840.0);
      expect(web.returningResultCalls.single, contains('window.scrollTo(0, 2000'));
      expect(web.returningResultCalls.single, contains('window.pageYOffset'));
    });

    test('falls back to the requested offset when the read is unparseable',
        () async {
      final web = FakeDsWebController(['undefined']);
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);

      expect(await resolver.scrollTo(900), 900.0);
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

  group('CaptureHeightResolver.resolveCapturePixelRatio', () {
    // A ~900px viewport is what a real phone/tablet gives the surface.
    const viewport = 900.0;

    test('renders a slice at exactly the printer paper width', () {
      for (final width in [390.0, 500.0]) {
        final ratio = CaptureHeightResolver.resolveCapturePixelRatio(
          captureWidth: width,
          sliceHeight: viewport,
        );
        expect(
          width * ratio,
          closeTo(CaptureHeightResolver.defaultPaperDots, 0.001),
          reason:
              'ImageParameter rescales to the paper width, so anything wider '
              'is decoded and transferred only to be thrown away',
        );
      }
    });

    test('no dimension of a real slice ever reaches the texture limit', () {
      const width = 390.0;
      final ratio = CaptureHeightResolver.resolveCapturePixelRatio(
        captureWidth: width,
        sliceHeight: viewport,
      );

      expect(width * ratio,
          lessThan(CaptureHeightResolver.maxTextureDimensionPx));
      expect(viewport * ratio,
          lessThan(CaptureHeightResolver.maxTextureDimensionPx));
    });

    test('the dimension cap overrides the paper-width target on a tall slice',
        () {
      // This is the regression that crashed the app: the old implementation
      // clamped to a legibility *floor* of 1.5, so a tall capture demanded a
      // texture the GPU could not allocate. Softness is the correct trade.
      const tall = 20000.0;
      final ratio = CaptureHeightResolver.resolveCapturePixelRatio(
        captureWidth: 390,
        sliceHeight: tall,
      );

      expect(ratio, lessThan(1.0));
      expect(
        tall * ratio,
        closeTo(CaptureHeightResolver.maxTextureDimensionPx, 0.001),
      );
    });

    test('caps on width too, not just height', () {
      final ratio = CaptureHeightResolver.resolveCapturePixelRatio(
        captureWidth: 9000,
        sliceHeight: 100,
      );

      expect(9000 * ratio,
          lessThanOrEqualTo(CaptureHeightResolver.maxTextureDimensionPx));
    });

    test('a caller-supplied maxDimensionPx is honoured', () {
      final ratio = CaptureHeightResolver.resolveCapturePixelRatio(
        captureWidth: 390,
        sliceHeight: 1000,
        maxDimensionPx: 500,
      );

      expect(1000 * ratio, closeTo(500, 0.001));
    });

    test('non-positive inputs return 1.0 rather than NaN/Infinity', () {
      for (final args in [
        (100.0, 0.0),
        (100.0, -5.0),
        (0.0, 100.0),
        (-5.0, 100.0),
      ]) {
        expect(
          CaptureHeightResolver.resolveCapturePixelRatio(
            captureWidth: args.$1,
            sliceHeight: args.$2,
          ),
          1.0,
        );
      }
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
