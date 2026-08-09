import 'package:equatable/equatable.dart';

/// Thermal printer paper width, expressed in dots.
///
/// The 500/595 defaults mirror the host app's `lib/core/env.dart`
/// (`printerWidthDotsHtml` / `printerWidthDotsBase64`) — keep them exactly.
class PaperWidth extends Equatable {
  final int dots;

  const PaperWidth(this.dots) : assert(dots > 0);

  static const PaperWidth html = PaperWidth(500);
  static const PaperWidth image = PaperWidth(595);

  @override
  List<Object?> get props => [dots];
}
