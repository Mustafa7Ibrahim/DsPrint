import 'package:equatable/equatable.dart';

import 'printer_interface_type.dart';

class PrinterDevice extends Equatable {
  final String id;
  final PrinterInterfaceType interfaceType;

  const PrinterDevice({required this.id, required this.interfaceType});

  bool get isValid => id.trim().isNotEmpty;

  @override
  List<Object?> get props => [id, interfaceType];

  // Equatable's own `==` also requires an identical runtimeType, so a
  // `PrinterDeviceModel` fresh off the discovery channel never equalled the
  // plain `PrinterDevice` read back from storage — the same printer, unequal.
  // That silently broke duplicate detection in the saved list, the selected
  // indicator, and "is this the active printer?". Two devices are the same
  // printer exactly when id and interface match, whatever class carries them.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterDevice &&
          other.id == id &&
          other.interfaceType == interfaceType;

  @override
  int get hashCode => Object.hash(id, interfaceType);
}
