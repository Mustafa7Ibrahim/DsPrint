import 'dart:math' show max, min;

import '../platform/ds_web_controller.dart';

/// Ports the capture-height algorithm duplicated in the host app's
/// `tax_invoice_screen.dart` and `logic_screenshoot.dart`. Pure logic over a
/// [DsWebController] — no Flutter widgets, so it is unit-testable.
class CaptureHeightResolver {
  final DsWebController web;
  final Duration pollInterval;
  final int maxPolls;
  final int requiredStableReads;

  const CaptureHeightResolver({
    required this.web,
    this.pollInterval = const Duration(milliseconds: 500),
    this.maxPolls = 40,
    this.requiredStableReads = 3,
  });

  /// The caller should only apply [trimToContentBottom]'s result when the
  /// delta from the current height exceeds this — skips a needless extra
  /// capture pass for a change too small to matter visually.
  static const double minTrimDeltaPx = 5;

  Future<void> expandDocument() async {
    await web.runJavaScript('''
        window.scrollTo(0, 0);
        document.body.style.overflow = 'visible';
        document.body.style.height = 'auto';
        document.body.style.minHeight = '0px';
        document.body.style.paddingBottom = '0px';
        document.body.style.marginBottom = '0px';
        document.documentElement.style.overflow = 'visible';
        document.documentElement.style.height = 'auto';
        document.documentElement.style.minHeight = '0px';
        document.documentElement.style.paddingBottom = '0px';

      ''');
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<double> readScrollHeight() async {
    final result = await web.runJavaScriptReturningResult(
      'document.documentElement.scrollHeight',
    );
    return double.tryParse(result) ?? 1000.0;
  }

  /// Polls `scrollHeight` until [requiredStableReads] consecutive reads
  /// differ by less than 1 px, or [maxPolls] is reached (whichever first).
  /// Unparseable reads fall back to the previous value.
  Future<double> stabilize(double initial) async {
    var prev = initial;
    var last = initial;
    var stableCount = 0;
    for (var i = 0; i < maxPolls; i++) {
      await Future.delayed(pollInterval);
      final result = await web.runJavaScriptReturningResult(
        'document.documentElement.scrollHeight',
      );
      final current = double.tryParse(result) ?? prev;
      last = current;
      if ((current - prev).abs() < 1.0) {
        stableCount++;
        if (stableCount >= requiredStableReads) return current;
      } else {
        stableCount = 0;
        prev = current;
      }
    }
    return last;
  }

  Future<double?> trimToContentBottom() async {
    final result = await web.runJavaScriptReturningResult('''
        (function() {
          var maxBottom = 0;
          document.querySelectorAll('body *').forEach(function(el) {
            var rect = el.getBoundingClientRect();
            if (rect.width > 0 && rect.height > 0) {
              var bottom = rect.bottom + window.pageYOffset;
              if (bottom > maxBottom) maxBottom = bottom;
            }
          });
          return maxBottom > 0 ? maxBottom : document.documentElement.scrollHeight;
        })()
      ''');
    final trimmed = double.tryParse(result);
    if (trimmed == null || trimmed <= 0) return null;
    return trimmed;
  }

  /// Both [expandDocument] and [restoreDocument] reset the scroll position, so
  /// a capture always starts at the top of the document no matter where the
  /// user had scrolled the preview to, and always leaves them back at the top
  /// rather than parked on the last slice.
  ///
  /// Scrolls the document so [offset] is at the top of the viewport, and
  /// returns where it *actually* landed.
  ///
  /// The read-back matters: the browser clamps at
  /// `scrollHeight - viewportHeight` and quantises to whole device pixels, so
  /// the last page of a document almost never lands where it was asked to. The
  /// caller uses the difference to trim the overlap instead of assuming the
  /// request was honoured — get this wrong and slices silently repeat or skip
  /// a band of the invoice.
  ///
  /// Scrolling (rather than shifting the content with a CSS transform) is
  /// deliberate: browsers rasterise long documents in tiles as they scroll,
  /// whereas `transform: translateY` can promote the whole body to one
  /// composited layer — reintroducing, inside the WebView's own renderer, the
  /// oversized-texture allocation this pipeline exists to avoid.
  Future<double> scrollTo(double offset) async {
    final result = await web.runJavaScriptReturningResult('''
        (function() {
          window.scrollTo(0, $offset);
          return window.pageYOffset;
        })()
      ''');
    return double.tryParse(result) ?? offset;
  }

  Future<void> restoreDocument() async {
    await web.runJavaScript('''
        window.scrollTo(0, 0);
        document.body.style.overflow = '';
        document.body.style.height = '';
        document.body.style.minHeight = '';
        document.body.style.paddingBottom = '';
        document.body.style.marginBottom = '';
        document.documentElement.style.overflow = '';
        document.documentElement.style.height = '';
        document.documentElement.style.minHeight = '';
        document.documentElement.style.paddingBottom = '';
      ''');
  }

  /// A conservative floor for Mali's `GL_MAX_TEXTURE_SIZE`, which is 4096 on
  /// older parts and 8192 on most current ones. Under-estimating is safe:
  /// because the capture is sliced, a smaller cap only means more slices —
  /// never a worse print. Over-estimating aborts the app, so this errs low.
  static const double maxTextureDimensionPx = 4096;

  /// Pixels of paper width the Star printer actually has — `PaperWidth.image`.
  /// Imported as a plain number rather than the value object to keep this
  /// service free of domain types, exactly as the rest of the class is.
  static const int defaultPaperDots = 595;

  /// The pixel ratio to rasterise one slice at.
  ///
  /// Driven by the printer, not the screen. `ImageParameter(bitmap, dots)`
  /// rescales whatever it is handed to [paperDots] wide, so every pixel of
  /// width beyond that is decoded, transferred and then thrown away — while
  /// still costing a proportionally larger GPU texture. Targeting the paper
  /// width exactly is both the sharpest possible print and the smallest
  /// allocation that achieves it.
  ///
  /// The [maxDimensionPx] cap is applied *after* the target and can push the
  /// ratio arbitrarily low. That ordering is the point: the previous
  /// implementation clamped to a legibility *floor* of 1.5, which is what let
  /// a tall invoice demand a texture the GPU could not allocate. A soft print
  /// beats an aborted process.
  static double resolveCapturePixelRatio({
    required double captureWidth,
    required double sliceHeight,
    int paperDots = defaultPaperDots,
    double maxDimensionPx = maxTextureDimensionPx,
  }) {
    if (captureWidth <= 0 || sliceHeight <= 0) return 1.0;
    final target = paperDots / captureWidth;
    final cap = maxDimensionPx / max(captureWidth, sliceHeight);
    return min(target, cap);
  }
}
