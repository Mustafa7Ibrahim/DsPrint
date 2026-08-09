import 'package:equatable/equatable.dart';

import '../../core/error/ds_print_failure.dart';
import '../../domain/entities/printer_device.dart';

sealed class PrinterDiscoveryState extends Equatable {
  const PrinterDiscoveryState();

  @override
  List<Object?> get props => [];
}

final class PrinterDiscoveryInitial extends PrinterDiscoveryState {
  const PrinterDiscoveryInitial();
}

final class PrinterDiscoveryLoading extends PrinterDiscoveryState {
  const PrinterDiscoveryLoading();
}

final class PrinterDiscoverySuccess extends PrinterDiscoveryState {
  final List<PrinterDevice> devices;
  final PrinterDevice? selected;

  const PrinterDiscoverySuccess(this.devices, this.selected);

  @override
  List<Object?> get props => [devices, selected];
}

final class PrinterDiscoveryFailure extends PrinterDiscoveryState {
  final DsPrintFailure failure;

  const PrinterDiscoveryFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}
