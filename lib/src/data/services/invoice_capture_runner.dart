import 'dart:convert';
import 'dart:developer' show log;
import 'dart:math' show min;

import '../../core/error/ds_print_exception.dart';
import '../platform/ds_image_boundary.dart';
import '../platform/ds_web_controller.dart';
import 'capture_height_resolver.dart';

/// Orchestrates the full capture pipeline so the preview screen
/// ([DsPrintWebSurface]) and the silent renderer (`OverlayInvoiceRenderer`)
/// share exactly one implementation, instead of the host app's duplicated
/// logic in `tax_invoice_screen.dart` and `logic_screenshoot.dart`.
///
/// The document is captured in **viewport-sized slices**, scrolled past a
/// WebView that never changes size. The previous design did the opposite — it
/// grew the WebView to the full document height and took one giant screenshot —
/// which asked the GPU for a texture taller than Mali's `GL_MAX_TEXTURE_SIZE`
/// on any invoice past roughly 3,000 logical px. The driver then failed every
/// allocation (`BAD ALLOC from gles_texture_egl_image_get_2d_template`) until
/// HWUI aborted the process with `EGL_BAD_ACCESS` on the RenderThread.
class InvoiceCaptureRunner {
  final DsWebController web;
  final DsImageBoundary boundary;
  final CaptureHeightResolver resolver;

  /// How long the WebView is given to repaint after a scroll before the frame
  /// is rasterised. Too short and a slice captures the previous scroll
  /// position, which shows up as a repeated band in the middle of the print.
  final Duration sliceSettleDelay;

  /// Backstop on the slice loop. At a ~900 px viewport this allows a document
  /// around 180,000 px tall — far past any real invoice, but finite, so a
  /// misbehaving page can never spin here forever.
  static const int maxSlices = 200;

  const InvoiceCaptureRunner({
    required this.web,
    required this.boundary,
    required this.resolver,
    this.sliceSettleDelay = const Duration(milliseconds: 180),
  });

  /// Returns one base64 PNG per slice, top to bottom. Consecutive slices abut
  /// exactly — no gap, no overlap — so printing them back to back on continuous
  /// paper reproduces the document.
  ///
  /// [viewportHeight] is the on-screen logical height of the captured boundary.
  Future<List<String>> run({
    required double captureWidth,
    required double viewportHeight,
  }) async {
    try {
      await resolver.expandDocument();

      final initial = await resolver.readScrollHeight();
      var contentHeight = await resolver.stabilize(initial);

      // Must be measured before the first scroll: the script reads
      // getBoundingClientRect, which is relative to the viewport.
      final trimmed = await resolver.trimToContentBottom();
      if (trimmed != null &&
          contentHeight - trimmed > CaptureHeightResolver.minTrimDeltaPx) {
        contentHeight = trimmed;
      }

      if (viewportHeight <= 0) {
        throw const CaptureException('capture boundary has no height');
      }

      final pixelRatio = CaptureHeightResolver.resolveCapturePixelRatio(
        captureWidth: captureWidth,
        sliceHeight: viewportHeight,
      );

      final slices = await _captureSlices(
        contentHeight: contentHeight,
        viewportHeight: viewportHeight,
        pixelRatio: pixelRatio,
      );
      if (slices.isEmpty) {
        throw const CaptureException('no slices were captured');
      }

      log('InvoiceCaptureRunner: content=${contentHeight.round()}px '
          'viewport=${viewportHeight.round()}px ratio=$pixelRatio '
          'slices=${slices.length} '
          'sliceSize=${(captureWidth * pixelRatio).round()}x'
          '${(viewportHeight * pixelRatio).round()}px');

      return slices;
    } finally {
      // A throw anywhere above must still restore the DOM and put the page back
      // at the top — the host app only did this on the happy path plus one
      // catch block, leaving the page permanently expanded on other error
      // paths.
      await resolver.restoreDocument();
    }
  }

  Future<List<String>> _captureSlices({
    required double contentHeight,
    required double viewportHeight,
    required double pixelRatio,
  }) async {
    final slices = <String>[];
    // Document pixels already captured. The next slice must start here exactly.
    var covered = 0.0;

    for (var i = 0; i < maxSlices && covered < contentHeight; i++) {
      final actual = await resolver.scrollTo(covered);
      // The viewport now shows [actual, actual + viewportHeight). At the bottom
      // of the document the browser clamps, so `actual` can be less than asked
      // and the top of this frame repeats rows the previous slice already has.
      final topSkip = (covered - actual).clamp(0.0, viewportHeight);
      final available = viewportHeight - topSkip;
      final wanted = min(available, contentHeight - covered);
      // No forward progress — stop rather than emit duplicate slices forever.
      if (wanted <= 0) break;

      await Future.delayed(sliceSettleDelay);

      final isWholeFrame = topSkip == 0 && wanted >= viewportHeight;
      final bytes = await boundary.toPngBytes(
        pixelRatio,
        topPx: isWholeFrame ? null : topSkip * pixelRatio,
        heightPx: isWholeFrame ? null : wanted * pixelRatio,
      );
      if (bytes == null) {
        throw const CaptureException('RepaintBoundary was not renderable');
      }
      final base64 = base64Encode(bytes);
      if (base64.isEmpty) {
        throw const CaptureException('encoded image was empty');
      }
      slices.add(base64);
      covered += wanted;
    }

    return slices;
  }
}
