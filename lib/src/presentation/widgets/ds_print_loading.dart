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

/// The package's one "please wait" overlay, shared by both print paths: a
/// translucent `Colors.black26` dim — matching the legacy `TaxInvoiceScreen` —
/// with the standard spinner on top.
///
/// Whatever is underneath stays visible: the invoice on the preview screen, the
/// host's own screen during a silent print. The wait then reads as "working on
/// this screen" rather than "the app navigated somewhere blank".
///
/// [AbsorbPointer] is what makes it a *blocking* wait. Without it the screen
/// showing through would still be tappable, and on the silent path that screen
/// is the live host UI — the user could scroll it, or start a second print,
/// under a scrim that says the app is busy.
class DsPrintCapturingScrim extends StatelessWidget {
  const DsPrintCapturingScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return const AbsorbPointer(
      child: ColoredBox(
        color: Colors.black26,
        child: DsPrintLoadingIndicator(),
      ),
    );
  }
}
