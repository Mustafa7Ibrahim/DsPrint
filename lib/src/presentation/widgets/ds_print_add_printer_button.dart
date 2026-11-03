import 'package:flutter/material.dart';

import '../../core/config/ds_print_strings.dart';
import '../../core/config/ds_print_theme.dart';
import '../../domain/entities/printer_device.dart';
import 'ds_print_add_printer_sheet.dart';

/// Drop-in "Add Printer" button for any screen of the host app — no
/// [PrinterPickerScreen] needed.
///
/// Tapping it opens the Add Printer sheet (choose USB / LAN / Bluetooth, scan,
/// pick). The printer the user adds is saved and becomes the active printer,
/// so every later print call — `DsPrint.printUrlSilently`, `printBase64`,
/// `printHtml` and the preview screen's Print button — goes to it. Then
/// [onPrinterAdded] fires with it.
///
/// For a fully custom control, call `DsPrint.addPrinter()` from your own
/// widget instead.
class DsPrintAddPrinterButton extends StatelessWidget {
  final ValueChanged<PrinterDevice>? onPrinterAdded;

  /// Defaults to the localised "Add Printer".
  final String? label;

  /// Merged over the default pill style; any field set here wins.
  final ButtonStyle? style;

  /// Whether the sheet offers Bluetooth. Null falls back to
  /// `DsPrintConfig.showBluetooth`, and then to showing it.
  final bool? showBluetooth;

  /// Whether the sheet offers LAN. Null falls back to
  /// `DsPrintConfig.showLan`, and then to showing it.
  final bool? showLan;

  const DsPrintAddPrinterButton({
    super.key,
    this.onPrinterAdded,
    this.label,
    this.style,
    this.showBluetooth,
    this.showLan,
  });

  Future<void> _handlePressed(BuildContext context) async {
    final device = await DsPrintAddPrinterSheet.show(
      context,
      showBluetooth: showBluetooth,
      showLan: showLan,
    );
    if (device != null) onPrinterAdded?.call(device);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    // Styled from the resolved theme rather than left to the host's
    // `elevatedButtonTheme`, so the pill matches the flavor colour in any
    // host — including one that never registered a button theme.
    final defaultStyle = ElevatedButton.styleFrom(
      backgroundColor: theme.primary,
      foregroundColor: theme.appBarForeground,
      minimumSize: const Size(220, 52),
      shape: const StadiumBorder(),
      textStyle: theme.actionStyle,
    );
    return ElevatedButton(
      style: style?.merge(defaultStyle) ?? defaultStyle,
      onPressed: () => _handlePressed(context),
      child: Text(label ?? DsPrintStrings.of(context).addPrinter),
    );
  }
}
