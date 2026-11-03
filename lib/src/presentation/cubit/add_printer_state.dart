import 'package:equatable/equatable.dart';

import '../../core/error/ds_print_failure.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/entities/printer_interface_type.dart';

sealed class AddPrinterState extends Equatable {
  const AddPrinterState();

  @override
  List<Object?> get props => [];
}

/// Step one: picking USB / LAN / Bluetooth. [selected] is null until the
/// user taps one, which is what keeps Next disabled.
final class AddPrinterChoosingType extends AddPrinterState {
  final PrinterInterfaceType? selected;

  const AddPrinterChoosingType([this.selected]);

  @override
  List<Object?> get props => [selected];
}

final class AddPrinterSearching extends AddPrinterState {
  final PrinterInterfaceType interfaceType;

  const AddPrinterSearching(this.interfaceType);

  @override
  List<Object?> get props => [interfaceType];
}

/// The scan finished. [devices] may be empty — that is a result, not an
/// error.
final class AddPrinterResults extends AddPrinterState {
  final PrinterInterfaceType interfaceType;
  final List<PrinterDevice> devices;

  const AddPrinterResults(this.interfaceType, this.devices);

  @override
  List<Object?> get props => [interfaceType, devices];
}

final class AddPrinterFailure extends AddPrinterState {
  final PrinterInterfaceType interfaceType;
  final DsPrintFailure failure;

  const AddPrinterFailure(this.interfaceType, this.failure);

  @override
  List<Object?> get props => [interfaceType, failure];
}

/// Saving the printer and making it active.
final class AddPrinterSaving extends AddPrinterState {
  final PrinterInterfaceType interfaceType;

  const AddPrinterSaving(this.interfaceType);

  @override
  List<Object?> get props => [interfaceType];
}

/// Terminal: [device] is saved and is now the active printer.
final class AddPrinterAdded extends AddPrinterState {
  final PrinterDevice device;

  const AddPrinterAdded(this.device);

  @override
  List<Object?> get props => [device];
}
