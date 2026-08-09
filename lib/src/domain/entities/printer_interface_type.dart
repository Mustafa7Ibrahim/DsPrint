/// Mirrors the host app's `EnumPrinterTypeConnection` — a Kotlin `when` block
/// matches on the exact capitalized string produced by [nativeName], so the
/// casing below must stay `Usb` / `Lan` / `Bluetooth` exactly; any other
/// casing silently falls back to USB at runtime.
enum PrinterInterfaceType {
  usb,
  lan,
  bluetooth;

  String get nativeName => switch (this) {
        PrinterInterfaceType.usb => 'Usb',
        PrinterInterfaceType.lan => 'Lan',
        PrinterInterfaceType.bluetooth => 'Bluetooth',
      };

  static PrinterInterfaceType fromNative(String? value) {
    if (value == null || value.isEmpty) return PrinterInterfaceType.usb;
    return PrinterInterfaceType.values.firstWhere(
      (e) => e.nativeName.toLowerCase() == value.toLowerCase(),
      orElse: () => PrinterInterfaceType.usb,
    );
  }
}
