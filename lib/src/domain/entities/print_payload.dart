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
  final String base64;

  const ImageBase64Payload(this.base64);

  @override
  String get raw => base64;

  @override
  PaperWidth get defaultWidth => PaperWidth.image;

  @override
  List<Object?> get props => [base64];
}
