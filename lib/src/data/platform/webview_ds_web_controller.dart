import 'package:webview_flutter/webview_flutter.dart';

import 'ds_web_controller.dart';

class WebViewDsWebController implements DsWebController {
  final WebViewController _controller;

  const WebViewDsWebController(this._controller);

  @override
  Future<void> loadUrl(String url, {Map<String, String> headers = const {}}) {
    return _controller.loadRequest(Uri.parse(url), headers: headers);
  }

  @override
  Future<void> runJavaScript(String script) =>
      _controller.runJavaScript(script);

  @override
  Future<String> runJavaScriptReturningResult(String script) async {
    final result = await _controller.runJavaScriptReturningResult(script);
    // The platform returns JSON-encoded scalars (quoted strings/numbers) —
    // strip the quotes, matching the legacy behaviour exactly.
    return result.toString().replaceAll('"', '');
  }
}
