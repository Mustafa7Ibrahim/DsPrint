import 'dart:typed_data';

abstract class DsImageBoundary {
  /// Returns PNG bytes, or null when the boundary is not currently renderable.
  Future<Uint8List?> toPngBytes(double pixelRatio);
}
