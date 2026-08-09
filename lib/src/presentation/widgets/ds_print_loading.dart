import 'package:flutter/material.dart';

import '../../core/config/ds_print_theme.dart';

/// The package's single loading affordance: a normal-sized, flavor-coloured
/// spinner.
///
/// The explicit [SizedBox] matters. A bare `CircularProgressIndicator` adopts
/// whatever constraints it is given, so under the tight constraints of a
/// `Positioned.fill` or an unconstrained `Stack` child it stretches to fill the
/// screen — the "full size loading indicator" this replaces.
class DsPrintLoadingIndicator extends StatelessWidget {
  static const double _diameter = 36;
  static const double _strokeWidth = 3;

  const DsPrintLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: _diameter,
        height: _diameter,
        child: CircularProgressIndicator(
          strokeWidth: _strokeWidth,
          color: DsPrintTheme.of(context).progressIndicator,
        ),
      ),
    );
  }
}

/// Dims the invoice preview while its capture runs, matching the legacy
/// `TaxInvoiceScreen`'s `Colors.black26` scrim. The page stays visible
/// underneath, so the wait reads as "working on this screen" rather than
/// "the app navigated somewhere blank".
class DsPrintCapturingScrim extends StatelessWidget {
  const DsPrintCapturingScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black26,
      child: DsPrintLoadingIndicator(),
    );
  }
}

/// Hides the headless capture WebView used by `DsPrint.printUrlSilently`.
///
/// Something opaque *has* to sit on top of that WebView: it must be painted at
/// least once for its `RepaintBoundary` to produce an image, so it can't be
/// moved off-screen, `Offstage`d or faded out with `Opacity` (all three skip
/// painting, and the boundary then has no layer to snapshot). What can change
/// is how the cover looks — it used to be a bare white fill with nothing on it,
/// which read as a frozen blank page; it now uses the host's own page
/// background plus the normal spinner, so a silent print looks like every other
/// loading state in the app.
class DsPrintCaptureCover extends StatelessWidget {
  const DsPrintCaptureCover({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DsPrintTheme.of(context).background,
      child: const DsPrintLoadingIndicator(),
    );
  }
}
