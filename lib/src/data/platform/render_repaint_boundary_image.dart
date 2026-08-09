import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'ds_image_boundary.dart';

class RepaintBoundaryImage implements DsImageBoundary {
  final GlobalKey key;

  const RepaintBoundaryImage(this.key);

  @override
  Future<Uint8List?> toPngBytes(double pixelRatio) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      // The legacy code leaked `image` on the null-byteData branch; disposing
      // in `finally` covers every path.
      image.dispose();
    }
  }
}
