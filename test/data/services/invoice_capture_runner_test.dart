import 'dart:convert';
import 'dart:math' show max, min;
import 'dart:typed_data';

import 'package:ds_print/src/core/error/ds_print_exception.dart';
import 'package:ds_print/src/data/platform/ds_image_boundary.dart';
import 'package:ds_print/src/data/platform/ds_web_controller.dart';
import 'package:ds_print/src/data/services/capture_height_resolver.dart';
import 'package:ds_print/src/data/services/invoice_capture_runner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves scripted `scrollHeight` reads (shared by `readScrollHeight` and
/// `stabilize`, which both run the identical script), a separate scripted
/// result for `trimToContentBottom`'s script, and a simulated scroll position —
/// each distinguished by content, since that is exactly how the real DOM
/// scripts differ.
///
/// The scroll simulation is the part that matters: a real browser clamps at
/// `scrollHeight - viewportHeight`, so the last page of a document lands short
/// of where it was asked to go. Faking that faithfully is what makes the
/// overlap-trimming assertions meaningful.
class FakeDsWebController implements DsWebController {
  FakeDsWebController({
    required List<String> scrollHeightResults,
    String? trimResult,
    this.documentHeight = 0,
    this.viewportHeight = 0,
  })  : _scrollHeightResults = scrollHeightResults,
        _trimResult = trimResult;

  final List<String> _scrollHeightResults;
  final String? _trimResult;

  /// Drives the clamp: `min(requested, documentHeight - viewportHeight)`.
  final double documentHeight;
  final double viewportHeight;

  int _scrollIndex = 0;

  final List<String> runJavaScriptCalls = [];
  final List<String> returningResultCalls = [];
  final List<double> scrollRequests = [];

  static final _scrollPattern = RegExp(r'window\.scrollTo\(0, ([-\d.]+)\)');

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

    if (script.contains('window.scrollTo')) {
      final requested =
          double.parse(_scrollPattern.firstMatch(script)!.group(1)!);
      scrollRequests.add(requested);
      final maxScroll = max(0.0, documentHeight - viewportHeight);
      return '${min(requested, maxScroll)}';
    }
    if (script.contains('querySelectorAll')) {
      return _trimResult ?? '0';
    }

    final value = _scrollIndex < _scrollHeightResults.length
        ? _scrollHeightResults[_scrollIndex]
        : _scrollHeightResults.last;
    _scrollIndex++;
    return value;
  }
}

typedef BoundaryCall = ({double pixelRatio, double? topPx, double? heightPx});

class FakeDsImageBoundary implements DsImageBoundary {
  FakeDsImageBoundary({this.errorToThrow, this.returnsNull = false});

  final Object? errorToThrow;
  final bool returnsNull;
  final List<BoundaryCall> calls = [];

  @override
  Future<Uint8List?> toPngBytes(
    double pixelRatio, {
    double? topPx,
    double? heightPx,
  }) async {
    calls.add((pixelRatio: pixelRatio, topPx: topPx, heightPx: heightPx));
    if (errorToThrow != null) throw errorToThrow!;
    if (returnsNull) return null;
    // Distinct bytes per call so slices can be told apart by the assertions.
    return Uint8List.fromList([calls.length]);
  }
}

void main() {
  const captureWidth = 390.0;
  const viewport = 800.0;

  double ratioFor(double sliceHeight) =>
      CaptureHeightResolver.resolveCapturePixelRatio(
        captureWidth: captureWidth,
        sliceHeight: sliceHeight,
      );

  InvoiceCaptureRunner runnerFor(
    FakeDsWebController web,
    FakeDsImageBoundary boundary,
  ) =>
      InvoiceCaptureRunner(
        web: web,
        boundary: boundary,
        resolver: CaptureHeightResolver(web: web, pollInterval: Duration.zero),
        sliceSettleDelay: Duration.zero,
      );

  /// index 0 -> initial readScrollHeight; then 3 more identical reads to
  /// satisfy the default requiredStableReads=3 in stabilize().
  List<String> stableReads(String height) => [height, height, height, height];

  group('InvoiceCaptureRunner.run slicing', () {
    test('a document shorter than the viewport is one bottom-cropped slice',
        () async {
      final web = FakeDsWebController(
        scrollHeightResults: stableReads('500'),
        trimResult: '0', // <=0 -> trimToContentBottom returns null, no trim
        documentHeight: 500,
        viewportHeight: viewport,
      );
      final boundary = FakeDsImageBoundary();

      final slices = await runnerFor(web, boundary)
          .run(captureWidth: captureWidth, viewportHeight: viewport);

      expect(slices, hasLength(1));
      expect(base64Decode(slices.single), [1]);
      // The frame is 800px tall but only 500px of it is content — the rest
      // would print as blank paper.
      expect(boundary.calls.single.topPx, 0);
      expect(boundary.calls.single.heightPx, closeTo(500 * ratioFor(viewport), 0.001));
    });

    test('a document of exactly two viewports is two uncropped slices',
        () async {
      final web = FakeDsWebController(
        scrollHeightResults: stableReads('1600'),
        trimResult: '0',
        documentHeight: 1600,
        viewportHeight: viewport,
      );
      final boundary = FakeDsImageBoundary();

      final slices = await runnerFor(web, boundary)
          .run(captureWidth: captureWidth, viewportHeight: viewport);

      expect(slices, hasLength(2));
      expect(web.scrollRequests, [0.0, 800.0]);
      // Whole frames: no crop, so no second rasterisation.
      expect(boundary.calls.every((c) => c.topPx == null && c.heightPx == null),
          isTrue);
    });

    test(
        'a partial last page is trimmed for the browser clamp, leaving no gap '
        'and no repeat', () async {
      // 2.5 viewports of content. The browser cannot scroll past 800 here
      // (1600 - 800), so the third frame repeats 400px the second already has.
      final web = FakeDsWebController(
        scrollHeightResults: stableReads('2000'),
        trimResult: '0',
        documentHeight: 2000,
        viewportHeight: viewport,
      );
      final boundary = FakeDsImageBoundary();
      final ratio = ratioFor(viewport);

      final slices = await runnerFor(web, boundary)
          .run(captureWidth: captureWidth, viewportHeight: viewport);

      expect(slices, hasLength(3));
      expect(web.scrollRequests, [0.0, 800.0, 1600.0]);

      // Frames 1 and 2 are whole; frame 3 lands at 1200 instead of 1600, so
      // its top 400px duplicate frame 2 and must be cut away.
      expect(boundary.calls[0].topPx, isNull);
      expect(boundary.calls[1].topPx, isNull);
      expect(boundary.calls[2].topPx, closeTo(400 * ratio, 0.001));
      expect(boundary.calls[2].heightPx, closeTo(400 * ratio, 0.001));

      // 800 + 800 + 400 == 2000: every document pixel captured exactly once.
      final captured = boundary.calls.fold<double>(
        0,
        (sum, c) => sum + (c.heightPx ?? viewport * ratio),
      );
      expect(captured, closeTo(2000 * ratio, 0.001));
    });

    test('every slice is rasterised at the same printer-driven pixel ratio',
        () async {
      final web = FakeDsWebController(
        scrollHeightResults: stableReads('2000'),
        trimResult: '0',
        documentHeight: 2000,
        viewportHeight: viewport,
      );
      final boundary = FakeDsImageBoundary();

      await runnerFor(web, boundary)
          .run(captureWidth: captureWidth, viewportHeight: viewport);

      expect(
        boundary.calls.map((c) => c.pixelRatio).toSet(),
        {ratioFor(viewport)},
      );
    });

    test('the page is scrolled back to the top afterwards', () async {
      final web = FakeDsWebController(
        scrollHeightResults: stableReads('2000'),
        trimResult: '0',
        documentHeight: 2000,
        viewportHeight: viewport,
      );

      await runnerFor(web, FakeDsImageBoundary())
          .run(captureWidth: captureWidth, viewportHeight: viewport);

      expect(
        web.runJavaScriptCalls.any((s) => s.contains('window.scrollTo(0, 0)')),
        isTrue,
      );
    });
  });

  group('InvoiceCaptureRunner.run trim threshold', () {
    test('applies the trim when the delta exceeds minTrimDeltaPx', () async {
      final web = FakeDsWebController(
        scrollHeightResults: stableReads('500'),
        trimResult: '490', // delta 10 > 5 -> trim applied
        documentHeight: 500,
        viewportHeight: viewport,
      );
      final boundary = FakeDsImageBoundary();

      await runnerFor(web, boundary)
          .run(captureWidth: captureWidth, viewportHeight: viewport);

      expect(boundary.calls.single.heightPx,
          closeTo(490 * ratioFor(viewport), 0.001));
    });

    test('does not apply the trim when the delta is <= minTrimDeltaPx',
        () async {
      final web = FakeDsWebController(
        scrollHeightResults: stableReads('500'),
        trimResult: '498', // delta 2 <= 5 -> trim NOT applied
        documentHeight: 500,
        viewportHeight: viewport,
      );
      final boundary = FakeDsImageBoundary();

      await runnerFor(web, boundary)
          .run(captureWidth: captureWidth, viewportHeight: viewport);

      expect(boundary.calls.single.heightPx,
          closeTo(500 * ratioFor(viewport), 0.001));
    });
  });

  group('InvoiceCaptureRunner.run error paths', () {
    test('a null result from toPngBytes throws CaptureException', () async {
      final web = FakeDsWebController(
        scrollHeightResults: stableReads('500'),
        trimResult: '0',
        documentHeight: 500,
        viewportHeight: viewport,
      );
      final boundary = FakeDsImageBoundary(returnsNull: true);

      await expectLater(
        runnerFor(web, boundary)
            .run(captureWidth: captureWidth, viewportHeight: viewport),
        throwsA(isA<CaptureException>()),
      );
    });

    test('a boundary with no height throws instead of dividing by zero',
        () async {
      final web = FakeDsWebController(
        scrollHeightResults: stableReads('500'),
        trimResult: '0',
      );

      await expectLater(
        runnerFor(web, FakeDsImageBoundary())
            .run(captureWidth: captureWidth, viewportHeight: 0),
        throwsA(isA<CaptureException>()),
      );
    });

    test('restoreDocument() still runs when the pipeline throws mid-way',
        () async {
      final web = FakeDsWebController(
        scrollHeightResults: stableReads('500'),
        trimResult: '0',
        documentHeight: 500,
        viewportHeight: viewport,
      );
      final boundary = FakeDsImageBoundary(
          errorToThrow: Exception('boundary render crashed'));

      await expectLater(
        runnerFor(web, boundary)
            .run(captureWidth: captureWidth, viewportHeight: viewport),
        throwsA(isA<Exception>()),
      );

      // This is the regression InvoiceCaptureRunner was written to fix: the
      // legacy code only restored the DOM on the happy path plus one catch
      // block, leaving the page permanently expanded on other error paths.
      expect(
        web.runJavaScriptCalls.any((s) => s.contains("style.overflow = ''")),
        isTrue,
        reason: 'restoreDocument() must still run when toPngBytes throws',
      );
    });
  });
}
