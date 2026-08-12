/// Renders a URL to one or more base64-encoded PNGs. Implemented in the
/// presentation layer (which owns the webview + RepaintBoundary); depended upon
/// here so the capture use case stays platform-free and fakeable in tests.
abstract class InvoiceRenderPort {
  /// Returns the page as vertical slices, top to bottom, each a base64 PNG.
  ///
  /// Slices exist because a GPU cannot allocate a texture as tall as a long
  /// invoice; consecutive slices abut exactly, so printing them back to back on
  /// continuous paper reproduces the page. A short receipt is a one-element
  /// list.
  Future<List<String>> renderUrlToPngSlices(String url);
}
