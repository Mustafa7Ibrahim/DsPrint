import 'dart:convert';
import 'dart:typed_data';

import 'package:ds_print/src/core/error/ds_print_exception.dart';
import 'package:ds_print/src/data/platform/ds_image_boundary.dart';
import 'package:ds_print/src/data/platform/ds_web_controller.dart';
import 'package:ds_print/src/data/services/capture_height_resolver.dart';
import 'package:ds_print/src/data/services/invoice_capture_runner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves scripted `scrollHeight` reads (shared by `readScrollHeight` and
/// `stabilize`, which both run the identical script) and a separate scripted
/// result for `trimToContentBottom`'s script, distinguished by content since
/// that's exactly how the real DOM script differs.
class FakeDsWebController implements DsWebController {
  FakeDsWebController(
      {required List<String> scrollHeightResults, String? trimResult})
      : _scrollHeightResults = scrollHeightResults,
        _trimResult = trimResult;

  final List<String> _scrollHeightResults;
  final String? _trimResult;
  int _scrollIndex = 0;

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

class FakeDsImageBoundary implements DsImageBoundary {
  FakeDsImageBoundary({this.bytesToReturn, this.errorToThrow});

  final Uint8List? bytesToReturn;
  final Object? errorToThrow;
  double? receivedPixelRatio;

  @override
  Future<Uint8List?> toPngBytes(double pixelRatio) async {
    receivedPixelRatio = pixelRatio;
    if (errorToThrow != null) throw errorToThrow!;
    return bytesToReturn;
  }
}

void main() {
  const captureWidth = 390.0;

  group('InvoiceCaptureRunner.run happy path', () {
    test('returns a non-empty base64 string', () async {
      // index 0 -> initial readScrollHeight; then 3 more identical reads to
      // satisfy the default requiredStableReads=3 in stabilize().
      final web = FakeDsWebController(
        scrollHeightResults: ['500', '500', '500', '500'],
        trimResult: '0', // <=0 -> trimToContentBottom returns null, no trim
      );
      final boundary =
          FakeDsImageBoundary(bytesToReturn: Uint8List.fromList([1, 2, 3, 4]));
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);
      final runner = InvoiceCaptureRunner(
          web: web, boundary: boundary, resolver: resolver);
      final heights = <double?>[];

      final result = await runner.run(
          captureWidth: captureWidth, onCaptureHeight: heights.add);

      expect(result, isNotEmpty);
      expect(base64Decode(result), [1, 2, 3, 4]);
      // finally-block contract: restoreDocument runs and height resets to null.
      expect(heights.last, isNull);
    });
  });

  group('InvoiceCaptureRunner.run trim threshold', () {
    test('applies the trim when the delta exceeds minTrimDeltaPx', () async {
      final web = FakeDsWebController(
        scrollHeightResults: ['500', '500', '500', '500'],
        trimResult: '490', // delta 10 > 5 -> trim applied
      );
      final boundary =
          FakeDsImageBoundary(bytesToReturn: Uint8List.fromList([9]));
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);
      final runner = InvoiceCaptureRunner(
          web: web, boundary: boundary, resolver: resolver);
      final heights = <double?>[];

      await runner.run(
          captureWidth: captureWidth, onCaptureHeight: heights.add);

      expect(heights, contains(490.0));
      expect(
        boundary.receivedPixelRatio,
        CaptureHeightResolver.resolvePixelRatio(
            captureWidth: captureWidth, height: 490),
      );
    });

    test('does not apply the trim when the delta is <= minTrimDeltaPx',
        () async {
      final web = FakeDsWebController(
        scrollHeightResults: ['500', '500', '500', '500'],
        trimResult: '498', // delta 2 <= 5 -> trim NOT applied
      );
      final boundary =
          FakeDsImageBoundary(bytesToReturn: Uint8List.fromList([9]));
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);
      final runner = InvoiceCaptureRunner(
          web: web, boundary: boundary, resolver: resolver);
      final heights = <double?>[];

      await runner.run(
          captureWidth: captureWidth, onCaptureHeight: heights.add);

      expect(heights, isNot(contains(498.0)));
      expect(
        boundary.receivedPixelRatio,
        CaptureHeightResolver.resolvePixelRatio(
            captureWidth: captureWidth, height: 500),
      );
    });
  });

  group('InvoiceCaptureRunner.run error paths', () {
    test('a null result from toPngBytes throws CaptureException', () async {
      final web = FakeDsWebController(
        scrollHeightResults: ['500', '500', '500', '500'],
        trimResult: '0',
      );
      final boundary = FakeDsImageBoundary(bytesToReturn: null);
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);
      final runner = InvoiceCaptureRunner(
          web: web, boundary: boundary, resolver: resolver);

      await expectLater(
        runner.run(captureWidth: captureWidth, onCaptureHeight: (_) {}),
        throwsA(isA<CaptureException>()),
      );
    });

    test(
        'restoreDocument() and onCaptureHeight(null) still run when the pipeline throws mid-way',
        () async {
      final web = FakeDsWebController(
        scrollHeightResults: ['500', '500', '500', '500'],
        trimResult: '0',
      );
      final boundary = FakeDsImageBoundary(
          errorToThrow: Exception('boundary render crashed'));
      final resolver =
          CaptureHeightResolver(web: web, pollInterval: Duration.zero);
      final runner = InvoiceCaptureRunner(
          web: web, boundary: boundary, resolver: resolver);
      final heights = <double?>[];

      await expectLater(
        runner.run(captureWidth: captureWidth, onCaptureHeight: heights.add),
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
      expect(heights.last, isNull);
    });
  });
}
