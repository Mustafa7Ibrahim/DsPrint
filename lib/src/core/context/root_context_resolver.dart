import 'package:flutter/widgets.dart';

import '../config/ds_print_config.dart';

/// Shared by the `DsPrint` facade and the headless `OverlayInvoiceRenderer`
/// so the "find a usable BuildContext with zero setup" algorithm exists in
/// exactly one place, no matter which entry point (`DsPrint.url`,
/// `DsPrint.printUrlSilently`, ...) triggers it.
class RootContextResolver {
  const RootContextResolver._();

  /// Order: the explicit [explicit] argument → [DsPrintConfig.current]'s
  /// `navigatorKey` (only set if the host opted into overriding it) → a walk
  /// from the binding's root element for the first [Navigator] found.
  ///
  /// That last step is what makes a bare `DsPrint.url("link")` call — no
  /// context, no prior setup — work: every host app has exactly one
  /// [Navigator] mounted under the root once `runApp` has painted a frame,
  /// so walking the live element tree finds it without the host ever having
  /// to hand ds_print a [BuildContext] or a [GlobalKey].
  static BuildContext? resolve({BuildContext? explicit}) {
    if (explicit != null) return explicit;
    final fromConfig = DsPrintConfig.current?.navigatorKey?.currentContext;
    if (fromConfig != null) return fromConfig;
    return _findNavigatorContext();
  }

  static BuildContext? _findNavigatorContext() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;

    BuildContext? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget is Navigator) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }

    visit(root);
    return found;
  }
}
