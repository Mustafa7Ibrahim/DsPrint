import 'package:flutter/material.dart';

import '../../core/config/ds_print_strings.dart';
import '../../core/config/ds_print_theme.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/entities/printer_interface_type.dart';
import '../cubit/printer_connection_state.dart';

/// Port of the host app's `PrinterDeviceItem`: selection dot, the connection
/// type over the printer's id, and a type icon. Uses [InkWell] directly — the
/// host's own `TapEffect` (an InkWell wrapper) lives outside this package and
/// can't be imported.
class PrinterDeviceTile extends StatelessWidget {
  final PrinterDevice device;
  final bool isSelected;
  final VoidCallback onTap;

  /// Off in the Add Printer sheet, where a scan result isn't "selected" yet.
  final bool showSelectionIndicator;

  /// Reachability shown as a dot and a short label under the id. Null shows
  /// nothing.
  final PrinterConnectionStatus? connectionStatus;

  const PrinterDeviceTile({
    super.key,
    required this.device,
    required this.isSelected,
    required this.onTap,
    this.showSelectionIndicator = true,
    this.connectionStatus,
  });

  static IconData iconFor(PrinterInterfaceType interfaceType) =>
      switch (interfaceType) {
        PrinterInterfaceType.usb => Icons.usb,
        PrinterInterfaceType.lan => Icons.lan,
        PrinterInterfaceType.bluetooth => Icons.bluetooth,
      };

  static const double _minTileHeight = 80;
  static const double _iconBoxSize = 56;
  static const double _indicatorSize = 22;

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    final strings = DsPrintStrings.of(context);
    final radius = BorderRadius.circular(16);
    final highlighted = showSelectionIndicator && isSelected;
    return Semantics(
      selected: highlighted,
      button: true,
      child: Material(
        color:
            highlighted ? theme.primary.withValues(alpha: 0.08) : theme.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: _minTileHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                borderRadius: radius, border: Border.all(color: theme.border)),
            child: Row(
              children: [
                if (showSelectionIndicator) ...[
                  Container(
                    width: _indicatorSize,
                    height: _indicatorSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? theme.selectedIndicator
                          : theme.unselectedIndicator,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.interfaceLabel(device.interfaceType),
                          style: theme.titleStyle),
                      const SizedBox(height: 6),
                      // IPs and MAC addresses must read left-to-right even in
                      // an Arabic layout.
                      Text(
                        device.id,
                        style: theme.bodyStyle,
                        textDirection: TextDirection.ltr,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (connectionStatus != null) ...[
                        const SizedBox(height: 6),
                        _ConnectionStatusLabel(status: connectionStatus!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: _iconBoxSize,
                  height: _iconBoxSize,
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconFor(device.interfaceType),
                      color: theme.primary, size: 30),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatusLabel extends StatelessWidget {
  final PrinterConnectionStatus status;

  const _ConnectionStatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    final strings = DsPrintStrings.of(context);
    final (color, label) = switch (status) {
      PrinterConnectionStatus.checking => (
          theme.unselectedIndicator,
          strings.checkingConnection
        ),
      PrinterConnectionStatus.connected => (
          theme.connectedIndicator,
          strings.connected
        ),
      PrinterConnectionStatus.disconnected => (
          theme.disconnectedIndicator,
          strings.notConnected
        ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: theme.bodyStyle.copyWith(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
