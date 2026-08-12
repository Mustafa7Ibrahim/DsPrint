import '../../domain/ports/invoice_render_port.dart';
import '../widgets/ds_print_web_surface.dart';

/// [InvoiceRenderPort] backed by a [DsPrintWebSurface] that is *already*
/// mounted and loaded — the one the user is looking at on the preview screen.
///
/// This is what the legacy `TaxInvoiceScreen` did: it captured its own webview.
/// Routing the preview screen through [OverlayInvoiceRenderer] instead meant
/// tapping Print downloaded and rendered the invoice a second time in a hidden
/// overlay, while an opaque cover hid the perfectly good copy underneath.
///
/// [renderUrlToPngSlices] ignores its `url` argument: the surface has finished
/// loading that exact page (the cubit only permits a capture from
/// `InvoicePreviewReady`), so re-requesting it would buy nothing but latency.
class SurfaceInvoiceRenderer implements InvoiceRenderPort {
  final DsPrintWebSurfaceHandle _surface;

  const SurfaceInvoiceRenderer(this._surface);

  @override
  Future<List<String>> renderUrlToPngSlices(String url) => _surface.capture();
}
