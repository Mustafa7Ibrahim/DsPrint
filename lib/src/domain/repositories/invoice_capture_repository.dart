import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/print_payload.dart';
import '../ports/invoice_render_port.dart';

abstract class InvoiceCaptureRepository {
  /// Captures [url] as printable PNG slices.
  ///
  /// [renderer] overrides the injected default for this call only. The headless
  /// path leaves it null and gets the overlay renderer; the preview screen
  /// passes a renderer bound to the webview it has already loaded, so no second
  /// copy of the page is ever created. Both paths share this one error mapping.
  Future<Either<DsPrintFailure, ImageBase64Payload>> captureUrl(
    String url, {
    InvoiceRenderPort? renderer,
  });
}
