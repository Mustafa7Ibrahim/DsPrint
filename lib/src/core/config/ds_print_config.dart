import 'package:flutter/widgets.dart';

import 'ds_print_theme.dart';

/// Optional overrides for host apps that want to customise ds_print's
/// defaults.
///
/// Calling `DsPrint.configure()` is **NOT required**. Every field here
/// defaults to null, and the package resolves a working navigator key,
/// theme, and print-result timeout on its own from the ambient
/// [BuildContext] wherever it's used. This class exists only for hosts that
/// want to override one of those resolved defaults.
class DsPrintConfig {
  final GlobalKey<NavigatorState>? navigatorKey;
  final DsPrintTheme? themeOverride;
  final Duration? printResultTimeout;

  const DsPrintConfig({
    this.navigatorKey,
    this.themeOverride,
    this.printResultTimeout,
  });

  /// Set once by [DsPrint.configure]; read by `RootContextResolver`, which
  /// both the facade and the headless overlay renderer share. Staying null
  /// (the default) is exactly what makes ds_print zero-configuration.
  static DsPrintConfig? current;
}
