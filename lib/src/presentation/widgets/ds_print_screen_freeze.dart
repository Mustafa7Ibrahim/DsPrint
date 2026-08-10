import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/config/ds_print_theme.dart';
import 'ds_print_loading.dart';

/// Takes a still frame of whatever the app is currently showing.
///
/// The silent print has to mount its capture WebView **full size and painted**.
/// Clipping it down to a sliver was tried and produced blank prints: an Android
/// platform view with (almost) no visible area on screen stops producing
/// content, so the `RepaintBoundary` snapshots nothing. Moving it off-screen,
/// `Offstage` and `Opacity(0)` fail for the related reason that they skip
/// painting entirely.
///
/// So something opaque must cover it. Making that something a photograph of the
/// screen the user was already on is the closest thing to leaving that screen
/// visible — which is the point of a *silent* print.
class DsPrintScreenFreeze {
  const DsPrintScreenFreeze._();

  /// Returns null when there is nothing to grab. Callers fall back to a plain
  /// opaque cover: cosmetically worse, functionally identical.
  ///
  /// Flutter-drawn content only. If the host screen is itself showing a
  /// platform view (a map, a webview) that region comes out blank — an
  /// acceptable trade for a cover that lasts one to three seconds.
  static Future<ui.Image?> capture() async {
    try {
      final views = RendererBinding.instance.renderViews;
      if (views.isEmpty) return null;
      final view = views.first;
      // `RenderObject.layer` is @protected to stop subclasses outside the
      // framework from *replacing* it. Reading the root view's layer is the
      // only way to snapshot a screen the package doesn't own — a host-side
      // RepaintBoundary would work, but requiring one breaks the package's
      // zero-configuration guarantee. Read-only, guarded by the type test
      // below and the catch around it.
      // ignore: invalid_use_of_protected_member
      final layer = view.layer;
      if (layer is! OffsetLayer) return null;
      // `RenderView.paintBounds` is already in physical pixels (the root layer
      // carries the devicePixelRatio transform), so the default pixelRatio of
      // 1.0 yields a native-resolution frame. Passing `size` instead would
      // capture only the top-left corner on any device with a ratio above 1.
      final bounds = view.paintBounds;
      if (bounds.isEmpty) return null;
      return await layer.toImage(bounds);
    } catch (_) {
      // A cosmetic nicety must never be able to fail a print.
      return null;
    }
  }
}

/// Covers the silent-print capture WebView with [frame] — the frozen screen —
/// plus the standard dim and spinner, so the wait looks like a loading overlay
/// on the user's own screen rather than a jump to a blank page.
class DsPrintFrozenScreenCover extends StatelessWidget {
  final ui.Image? frame;

  const DsPrintFrozenScreenCover({super.key, this.frame});

  @override
  Widget build(BuildContext context) {
    final frame = this.frame;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (frame == null)
          ColoredBox(color: DsPrintTheme.of(context).background)
        else
          // BoxFit.fill, not cover: the frame is the exact screen rectangle,
          // so stretching it to the same rectangle is a 1:1 mapping and
          // nothing gets cropped.
          RawImage(image: frame, fit: BoxFit.fill),
        const DsPrintCapturingScrim(),
      ],
    );
  }
}
