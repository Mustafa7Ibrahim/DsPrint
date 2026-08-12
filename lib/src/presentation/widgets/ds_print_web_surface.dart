import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config/ds_print_responsive.dart';
import '../../core/config/ds_print_strings.dart';
import '../../data/platform/render_repaint_boundary_image.dart';
import '../../data/platform/webview_ds_web_controller.dart';
import '../../data/services/capture_height_resolver.dart';
import '../../data/services/invoice_capture_runner.dart';

/// Owns the WebView + RepaintBoundary shared by both the interactive
/// preview screen and the headless overlay renderer, so the two only ever
/// differ in what surrounds this widget — never in how the page is loaded
/// or captured.
///
/// **The widget tree built here is deliberately constant.** It used to switch
/// between `SizedBox.expand(webView)` while idle and
/// `SingleChildScrollView(RepaintBoundary(...))` while capturing, growing the
/// WebView to the full document height in the process. Two native consequences
/// followed, and together they crashed the app:
///
/// * `Widget.canUpdate` compares `runtimeType`, so swapping `SizedBox` for
///   `SingleChildScrollView` unmounted the whole subtree — destroying and
///   recreating the native platform view twice per capture. Tearing down a
///   `Surface` while HWUI still has a draw in flight against it aborts the
///   process with `EGL_BAD_ACCESS`.
/// * A platform view laid out at the document height needs a backing surface
///   `height × devicePixelRatio` physical px tall, which passes Mali's
///   `GL_MAX_TEXTURE_SIZE` at around 3,000 logical px.
///
/// So the WebView is created once, sized to the viewport, and never resized or
/// reparented; [InvoiceCaptureRunner] scrolls the document past it instead.
class DsPrintWebSurface extends StatefulWidget {
  final String url;
  final bool autoCaptureOnLoad;
  final void Function(DsPrintWebSurfaceHandle handle)? onReady;
  final void Function(List<String> slices)? onCaptured;
  final void Function(Object error)? onFailed;
  final VoidCallback? onPageFinished;

  const DsPrintWebSurface({
    super.key,
    required this.url,
    this.autoCaptureOnLoad = false,
    this.onReady,
    this.onCaptured,
    this.onFailed,
    this.onPageFinished,
  });

  @override
  State<DsPrintWebSurface> createState() => _DsPrintWebSurfaceState();
}

class _DsPrintWebSurfaceState extends State<DsPrintWebSurface> {
  late final WebViewController _controller;

  /// Built once and held, not constructed in `build`. Even with a stable tree
  /// shape this guarantees the element backing the platform view is only ever
  /// updated, never replaced.
  late final Widget _webView;

  final GlobalKey _boundaryKey = GlobalKey();
  bool _hasAutoCaptured = false;
  bool _hasRequestedUrl = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {},
          onPageFinished: (_) => _handlePageFinished(),
          onWebResourceError: (error) {
            // Surfaces load failures that would otherwise be silently
            // swallowed (e.g. the invoice URL pointing at a non-renderable
            // resource) — mirrors tax_invoice_screen.dart's own logging.
            debugPrint(
              'DsPrintWebSurface: webResourceError mainFrame=${error.isForMainFrame} '
              'code=${error.errorCode} desc=${error.description} url=${error.url}',
            );
          },
        ),
      );
    _webView = WebViewWidget(controller: _controller);
    widget.onReady?.call(DsPrintWebSurfaceHandle._(this));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The Accept-Language header reads `Localizations`, an InheritedWidget.
    // Resolving it in initState throws
    // `dependOnInheritedWidgetOfExactType<_LocalizationsScope>() ... was
    // called before initState() completed`, so the load is deferred to here —
    // the earliest point an inherited lookup is legal. Guarded so a later
    // dependency change (locale switch, theme change) never reloads the page
    // mid-capture.
    if (_hasRequestedUrl) return;
    _hasRequestedUrl = true;
    _controller.loadRequest(
      Uri.parse(widget.url),
      headers: {'Accept-Language': DsPrintStrings.of(context).languageCode},
    );
  }

  void _handlePageFinished() {
    widget.onPageFinished?.call();
    if (!widget.autoCaptureOnLoad || _hasAutoCaptured) return;
    // Guards against the duplicate onPageFinished calls some redirects
    // trigger — without this a second capture would race the first.
    _hasAutoCaptured = true;
    // Errors are reported through widget.onFailed inside _capture(); .ignore()
    // just stops that same rejection from also being logged as unhandled.
    _capture().ignore();
  }

  Future<List<String>> _capture() async {
    final webController = WebViewDsWebController(_controller);
    final runner = InvoiceCaptureRunner(
      web: webController,
      boundary: RepaintBoundaryImage(_boundaryKey),
      resolver: CaptureHeightResolver(web: webController),
    );
    try {
      // Measured from the boundary itself rather than from
      // DsPrintResponsive.captureWidth: on a screen narrower than the nominal
      // capture width the SizedBox below is squeezed, and a pixel ratio derived
      // from the nominal value would produce a capture that is not the paper
      // width after all.
      final box =
          _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
      final size = box?.size ?? Size.zero;

      final slices = await runner.run(
        captureWidth: size.width,
        viewportHeight: size.height,
      );
      widget.onCaptured?.call(slices);
      return slices;
    } catch (e) {
      widget.onFailed?.call(e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Constrained to the capture width at all times, not just while capturing.
    // The document therefore never reflows between what the user previewed and
    // what gets printed, and on a tablet the preview becomes a receipt-width
    // column — which is exactly what comes out of the printer.
    return Center(
      child: SizedBox(
        width: DsPrintResponsive.captureWidth(context),
        child: RepaintBoundary(
          key: _boundaryKey,
          child: ColoredBox(
            color: Colors.white,
            child: SizedBox.expand(child: _webView),
          ),
        ),
      ),
    );
  }
}

/// Handle to imperatively trigger a capture from outside [DsPrintWebSurface],
/// obtained via [DsPrintWebSurface.onReady].
class DsPrintWebSurfaceHandle {
  final _DsPrintWebSurfaceState _state;

  const DsPrintWebSurfaceHandle._(this._state);

  Future<List<String>> capture() => _state._capture();
}
