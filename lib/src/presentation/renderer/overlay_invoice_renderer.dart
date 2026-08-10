import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/context/root_context_resolver.dart';
import '../../core/error/ds_print_exception.dart';
import '../../domain/ports/invoice_render_port.dart';
import '../widgets/ds_print_screen_freeze.dart';
import '../widgets/ds_print_web_surface.dart';

/// The headless path behind `DsPrint.printUrlSilently` — loads [url] into a
/// full-size on-screen [DsPrintWebSurface] and resolves once the shared
/// capture pipeline finishes. The WebView is hidden behind a still frame of
/// the screen the user was already on, so the wait reads as a loading overlay
/// on that screen rather than a jump to a blank page.
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

    // Grabbed before the overlay goes up, so it shows the app as the user last
    // saw it. Null is fine — the cover falls back to a plain opaque fill.
    final frozenScreen = await DsPrintScreenFreeze.capture();

    final completer = Completer<String>();
    final entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Full size and unclipped, deliberately. An Android platform view
          // with (almost) no visible area stops producing content, and the
          // capture then comes back blank — clipping this down to hide it was
          // tried and printed empty paper. It has to be painted for real, and
          // covered.
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
          Positioned.fill(
            child: DsPrintFrozenScreenCover(frame: frozenScreen),
          ),
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
      // The entry unmounts on the next frame, so the RawImage can still be
      // painting this image right now; disposing it inline would tear it out
      // from under that last frame.
      if (frozenScreen != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => frozenScreen.dispose());
      }
    }
  }
}
