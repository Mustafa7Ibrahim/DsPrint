import 'package:flutter/material.dart';

import '../../core/config/ds_print_theme.dart';
import '../../domain/entities/printer_device.dart';

/// Port of the host app's `PrinterDeviceItem`. Uses [InkWell] directly —
/// the host's own `TapEffect` (an InkWell wrapper) lives outside this
/// package and can't be imported.
class PrinterDeviceTile extends StatelessWidget {
  final PrinterDevice device;
  final bool isSelected;
  final VoidCallback onTap;

  const PrinterDeviceTile({
    super.key,
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  static const double _tileHeight = 80;
  static const double _iconBoxSize = 50;
  static const double _indicatorSize = 26;
  static const double _horizontalPadding = 10;

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    final radius = BorderRadius.circular(16);
    return Material(
      color: theme.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: _tileHeight,
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          decoration: BoxDecoration(
              borderRadius: radius, border: Border.all(color: theme.border)),
          child: Row(
            children: [
              Container(
                width: _iconBoxSize,
                height: _iconBoxSize,
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.print, color: theme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.interfaceType.nativeName,
                        style: theme.titleStyle),
                    const SizedBox(height: 12),
                    Text(device.id, style: theme.bodyStyle),
                  ],
                ),
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}
