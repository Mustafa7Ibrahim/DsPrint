import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'ds_image_boundary.dart';

class RepaintBoundaryImage implements DsImageBoundary {
  final GlobalKey key;

  const RepaintBoundaryImage(this.key);

  @override
  Future<Uint8List?> toPngBytes(
    double pixelRatio, {
    double? topPx,
    double? heightPx,
  }) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final band = await _crop(image, topPx, heightPx);
      try {
        final byteData = await band.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      } finally {
        // Only when _crop actually allocated one — disposing `image` twice
        // would throw, and it is disposed by the outer finally either way.
        if (!identical(band, image)) band.dispose();
      }
    } finally {
      // The legacy code leaked `image` on the null-byteData branch; disposing
      // in `finally` covers every path.
      image.dispose();
    }
  }

  /// Returns [source] itself when the requested band is the whole image, so the
  /// common case (a full, uncropped slice) costs no second rasterisation.
  Future<ui.Image> _crop(ui.Image source, double? topPx, double? heightPx) async {
    final top = (topPx ?? 0).round().clamp(0, source.height);
    final height =
        (heightPx?.round() ?? source.height - top).clamp(0, source.height - top);
    if (top == 0 && height == source.height) return source;
    // A zero-height band would produce an image the PNG encoder rejects; one
    // row is the smallest thing that still encodes.
    final safeHeight = height == 0 ? 1 : height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final width = source.width.toDouble();
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, top.toDouble(), width, safeHeight.toDouble()),
      Rect.fromLTWH(0, 0, width, safeHeight.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    try {
      // Strictly smaller than `source`, which the GPU has already allocated —
      // so this can never be the allocation that fails.
      return await picture.toImage(source.width, safeHeight);
    } finally {
      picture.dispose();
    }
  }
}
