import 'dart:convert';

import '../../core/error/ds_print_exception.dart';
import '../platform/ds_image_boundary.dart';
import '../platform/ds_web_controller.dart';
import 'capture_height_resolver.dart';

/// Orchestrates the full capture pipeline so the preview screen
/// ([DsPrintWebSurface]) and the silent renderer (`OverlayInvoiceRenderer`)
/// share exactly one implementation, instead of the host app's duplicated
/// logic in `tax_invoice_screen.dart` and `logic_screenshoot.dart`.
class InvoiceCaptureRunner {
  final DsWebController web;
  final DsImageBoundary boundary;
  final CaptureHeightResolver resolver;

  const InvoiceCaptureRunner({
    required this.web,
    required this.boundary,
    required this.resolver,
  });

  Future<String> run({
    required double captureWidth,
    required void Function(double?) onCaptureHeight,
  }) async {
    try {
      await resolver.expandDocument();

      final initial = await resolver.readScrollHeight();
      onCaptureHeight(initial);

      var finalHeight = await resolver.stabilize(
        initial,
        onHeight: onCaptureHeight,
      );

      final trimmed = await resolver.trimToContentBottom();
      if (trimmed != null &&
          finalHeight - trimmed > CaptureHeightResolver.minTrimDeltaPx) {
        finalHeight = trimmed;
        onCaptureHeight(finalHeight);
        await Future.delayed(const Duration(milliseconds: 150));
      }

      final pixelRatio = CaptureHeightResolver.resolvePixelRatio(
        captureWidth: captureWidth,
        height: finalHeight,
      );

      final bytes = await boundary.toPngBytes(pixelRatio);
      if (bytes == null) {
        throw const CaptureException('RepaintBoundary was not renderable');
      }

      final base64 = base64Encode(bytes);
      if (base64.isEmpty) {
        throw const CaptureException('encoded image was empty');
      }
      return base64;
    } finally {
      // A throw anywhere above must still restore the DOM and collapse the
      // widget back to its normal (non-capture) height — the host app only
      // did this on the happy path plus one catch block, leaving the page
      // permanently expanded on other error paths.
      await resolver.restoreDocument();
      onCaptureHeight(null);
    }
  }
}
