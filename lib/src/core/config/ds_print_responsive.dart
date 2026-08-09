import 'package:flutter/widgets.dart';

/// Mirrors the host app's own tablet/print-capture sizing exactly, so
/// ds_print's screens and capture pipeline match today's output:
/// `lib/core/responsive/Figma.dart:24` (550 tablet threshold) and
/// `tax_invoice_screen.dart:161`/`:340` (500/390 capture width, 350
/// container width).
class DsPrintResponsive {
  const DsPrintResponsive._();

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 550;

  static double captureWidth(BuildContext context) =>
      isTablet(context) ? 500.0 : 390.0;

  static double? captureContainerWidth(BuildContext context) =>
      isTablet(context) ? 350 : null;
}
