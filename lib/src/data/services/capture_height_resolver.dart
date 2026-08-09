import 'dart:math' show sqrt;

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
  /// [onHeight] fires on every poll so the caller can grow the webview live
  /// while measuring. Unparseable reads fall back to the previous value.
  Future<double> stabilize(
    double initial, {
    void Function(double)? onHeight,
  }) async {
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
      onHeight?.call(current);
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

  Future<void> restoreDocument() async {
    await web.runJavaScript('''
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

  /// Scales pixel ratio so total pixels stay near 8 M — keeps the base64
  /// payload small enough for memory and the native print channel's buffer.
  /// Guards against non-positive inputs (which would otherwise produce
  /// NaN/Infinity) by returning the 1.5 lower clamp.
  static double resolvePixelRatio({
    required double captureWidth,
    required double height,
  }) {
    if (captureWidth <= 0 || height <= 0) return 1.5;
    final ratio = sqrt(8000000.0 / (captureWidth * height));
    return ratio.clamp(1.5, 10.0);
  }
}
