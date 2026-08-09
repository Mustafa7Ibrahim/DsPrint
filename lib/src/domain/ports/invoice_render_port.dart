/// Renders a URL to a base64-encoded PNG. Implemented in the presentation
/// layer (which owns the webview + RepaintBoundary); depended upon here so the
/// capture use case stays platform-free and fakeable in tests.
abstract class InvoiceRenderPort {
  Future<String> renderUrlToBase64Png(String url);
}
