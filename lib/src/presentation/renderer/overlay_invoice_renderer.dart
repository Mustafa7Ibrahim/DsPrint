import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/context/root_context_resolver.dart';
import '../../core/error/ds_print_exception.dart';
import '../../domain/ports/invoice_render_port.dart';
import '../widgets/ds_print_loading.dart';
import '../widgets/ds_print_web_surface.dart';

/// The headless path behind `DsPrint.printUrlSilently` — loads [url] into an
/// off-widget-tree-position-but-on-screen [DsPrintWebSurface] (see the
/// comment below) and resolves once the shared capture pipeline finishes.
class OverlayInvoiceRenderer implements InvoiceRenderPort {
  static const _timeout = Duration(seconds: 60);

  @override
  Future<String> renderUrlToBase64Png(String url) async {
    final context = RootContextResolver.resolve();
    if (context == null) {
      throw const CaptureException('no BuildContext available');
    }
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) {
      throw const CaptureException('no overlay');
    }

    final completer = Completer<String>();
    final entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // The WebView must actually be painted at least once for its
          // RepaintBoundary to produce an image, so it is deliberately
          // mounted on-screen (not positioned off the viewport) and hidden
          // by opaquely covering it instead — see [DsPrintCaptureCover].
          Positioned.fill(
            child: DsPrintWebSurface(
              url: url,
              autoCaptureOnLoad: true,
              onCaptured: (base64) {
                if (!completer.isCompleted) completer.complete(base64);
              },
              onFailed: (error) {
                if (!completer.isCompleted) completer.completeError(error);
              },
            ),
          ),
          const Positioned.fill(child: DsPrintCaptureCover()),
        ],
      ),
    );

    try {
      overlay.insert(entry);
      return await completer.future.timeout(
        _timeout,
        onTimeout: () => throw const CaptureException('timeout'),
      );
    } finally {
      // A failure/timeout must never leave an invisible WebView covering the
      // app — removing here covers every exit path, not just the happy one.
      entry.remove();
    }
  }
}
