import 'package:flutter/widgets.dart';

/// Mirrors the host app's own tablet/print-capture sizing exactly, so
/// ds_print's screens and capture pipeline match today's output:
/// `lib/core/responsive/Figma.dart:24` (550 tablet threshold) and
/// `tax_invoice_screen.dart:340` (350 capture container width, 12px padding).
class DsPrintResponsive {
  const DsPrintResponsive._();

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 550;

  /// The logical width the invoice is laid out and captured at.
  ///
  /// **This is what sets the printed text size.** The Star SDK always rescales
  /// the captured image to `PaperWidth.image` dots, so the magnification the
  /// page gets on paper is `paperDots / (this - capturePadding)` — a *narrower*
  /// capture prints *bigger* text. 350 on a tablet is around 1.8x; laying the
  /// same page out at 500 would drop it to 1.2x and print noticeably small.
  ///
  /// Null on a phone means "as wide as the screen", which is what the capture
  /// container has always done there — a phone screen is already about the
  /// right width for a receipt.
  static double? captureWidth(BuildContext context) =>
      isTablet(context) ? 350.0 : null;

  /// White margin captured either side of the page, inside the boundary and so
  /// part of the printed image.
  static const EdgeInsets capturePadding =
      EdgeInsets.symmetric(horizontal: 12);
}
