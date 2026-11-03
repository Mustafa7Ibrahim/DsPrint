import 'package:equatable/equatable.dart';

import '../../core/error/ds_print_failure.dart';
import '../../domain/entities/printer_device.dart';

sealed class SavedPrintersState extends Equatable {
  const SavedPrintersState();

  @override
  List<Object?> get props => [];
}

final class SavedPrintersLoading extends SavedPrintersState {
  const SavedPrintersLoading();
}

/// [selected] is the printer every print call goes to; `null` when the user
/// hasn't chosen one (or removed the one they had).
final class SavedPrintersLoaded extends SavedPrintersState {
  final List<PrinterDevice> printers;
  final PrinterDevice? selected;

  const SavedPrintersLoaded(this.printers, this.selected);

  @override
  List<Object?> get props => [printers, selected];
}

final class SavedPrintersFailure extends SavedPrintersState {
  final DsPrintFailure failure;

  const SavedPrintersFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}
