import 'dart:typed_data';

abstract class DsImageBoundary {
  /// Returns PNG bytes, or null when the boundary is not currently renderable.
  ///
  /// [topPx] and [heightPx] select a horizontal band of the rasterised image,
  /// measured in captured pixels (i.e. already multiplied by [pixelRatio]).
  /// Both null captures the whole boundary.
  ///
  /// The band exists for sliced capture: the first and last slice of a document
  /// usually overlap their neighbour, because the browser clamps the scroll
  /// offset at the bottom of the page and because the content rarely ends on an
  /// exact viewport boundary. Cropping here rather than in the caller keeps the
  /// `ui.Image` — and its disposal — inside the platform layer.
  Future<Uint8List?> toPngBytes(
    double pixelRatio, {
    double? topPx,
    double? heightPx,
  });
}
