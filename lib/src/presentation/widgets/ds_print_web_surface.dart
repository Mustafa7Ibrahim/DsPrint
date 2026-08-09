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
class DsPrintWebSurface extends StatefulWidget {
  final String url;
  final bool autoCaptureOnLoad;
  final void Function(DsPrintWebSurfaceHandle handle)? onReady;
  final void Function(String base64)? onCaptured;
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
  final GlobalKey _boundaryKey = GlobalKey();
  final ValueNotifier<double?> _captureHeight = ValueNotifier<double?>(null);
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

  Future<String> _capture() async {
    final captureWidth = DsPrintResponsive.captureWidth(context);
    final webController = WebViewDsWebController(_controller);
    final runner = InvoiceCaptureRunner(
      web: webController,
      boundary: RepaintBoundaryImage(_boundaryKey),
      resolver: CaptureHeightResolver(web: webController),
    );
    try {
      final base64 = await runner.run(
        captureWidth: captureWidth,
        onCaptureHeight: (height) {
          if (!mounted) return;
          _captureHeight.value = height;
        },
      );
      widget.onCaptured?.call(base64);
      return base64;
    } catch (e) {
      widget.onFailed?.call(e);
      rethrow;
    }
  }

  @override
  void dispose() {
    _captureHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double?>(
      valueListenable: _captureHeight,
      builder: (context, height, _) {
        final webView = WebViewWidget(controller: _controller);
        if (height == null) {
          // Rendered directly, with no RepaintBoundary: on Android the
          // WebView can fall back to Hybrid Composition (a native
          // SurfaceView), which cannot paint into an offscreen
          // RepaintBoundary layer and renders black. The boundary below is
          // only ever mounted while a capture is in progress.
          return SizedBox.expand(child: webView);
        }
        return SingleChildScrollView(
          child: RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              color: Colors.white,
              width: DsPrintResponsive.captureContainerWidth(context),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: double.infinity, height: height, child: webView),
            ),
          ),
        );
      },
    );
  }
}

/// Handle to imperatively trigger a capture from outside [DsPrintWebSurface],
/// obtained via [DsPrintWebSurface.onReady].
class DsPrintWebSurfaceHandle {
  final _DsPrintWebSurfaceState _state;

  const DsPrintWebSurfaceHandle._(this._state);

  Future<String> capture() => _state._capture();
}
