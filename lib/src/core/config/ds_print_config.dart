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

  /// How long the pre-print / Printers-screen connection check waits for the
  /// printer to answer. Null uses 3 seconds for USB/LAN and 5 seconds for
  /// Bluetooth.
  final Duration? connectionCheckTimeout;

  /// Whether the Add Printer sheet offers Bluetooth. Null (the default) shows
  /// it. A `showBluetooth:` passed to [DsPrintAddPrinterButton],
  /// [PrinterPickerScreen], `DsPrint.addPrinter` or `DsPrint.selectDevice`
  /// overrides this for that one use.
  final bool? showBluetooth;

  /// Whether the Add Printer sheet offers LAN. Same rules as [showBluetooth].
  final bool? showLan;

  const DsPrintConfig({
    this.navigatorKey,
    this.themeOverride,
    this.printResultTimeout,
    this.connectionCheckTimeout,
    this.showBluetooth,
    this.showLan,
  });

  /// Set once by [DsPrint.configure]; read by `RootContextResolver`, which
  /// both the facade and the headless overlay renderer share. Staying null
  /// (the default) is exactly what makes ds_print zero-configuration.
  static DsPrintConfig? current;
}
