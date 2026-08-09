/// Free of webview types — this abstraction is the entire reason the
/// capture algorithm ([CaptureHeightResolver]) is unit-testable.
abstract class DsWebController {
  Future<void> loadUrl(String url, {Map<String, String> headers = const {}});

  Future<void> runJavaScript(String script);

  Future<String> runJavaScriptReturningResult(String script);
}
