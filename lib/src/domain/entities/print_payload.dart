import 'package:equatable/equatable.dart';

import '../../core/value/paper_width.dart';

/// Deliberately free of native wire-format strings (`"html"`/`"base64"`) —
/// that mapping is a data-layer concern for a later phase.
sealed class PrintPayload extends Equatable {
  const PrintPayload();

  String get raw;

  bool get isEmpty => raw.trim().isEmpty;

  PaperWidth get defaultWidth;
}

final class HtmlPayload extends PrintPayload {
  final String html;

  const HtmlPayload(this.html);

  @override
  String get raw => html;

  @override
  PaperWidth get defaultWidth => PaperWidth.html;

  @override
  List<Object?> get props => [html];
}

final class ImageBase64Payload extends PrintPayload {
  /// One base64 PNG per vertical slice of the document, top to bottom.
  final List<String> slices;

  const ImageBase64Payload(this.slices);

  /// A payload that is a single, already-captured image — the shape
  /// `DsPrint.printBase64` has always taken. Not `const`: a list literal
  /// holding a parameter is not a constant expression.
  ImageBase64Payload.single(String base64) : slices = [base64];

  /// Slices are joined with a newline, which is unambiguous because base64's
  /// alphabet is `A–Z a–z 0–9 + / =` and `base64Encode` never wraps. The native
  /// side splits on it; a single-slice payload contains no separator and so
  /// travels exactly as it did before slicing existed.
  static const String separator = '\n';

  @override
  String get raw => slices.join(separator);

  @override
  PaperWidth get defaultWidth => PaperWidth.image;

  @override
  List<Object?> get props => [slices];
}
