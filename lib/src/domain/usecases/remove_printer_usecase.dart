import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';
import '../repositories/saved_printers_repository.dart';
import 'clear_selected_printer_usecase.dart';
import 'get_selected_printer_usecase.dart';

/// Removes [PrinterDevice] from the user's list. Removing the active printer
/// also clears the selection, so a print never goes to a printer the user
/// deleted — it asks for one instead.
class RemovePrinterUseCase {
  final SavedPrintersRepository _savedPrinters;
  final GetSelectedPrinterUseCase _getSelectedPrinter;
  final ClearSelectedPrinterUseCase _clearSelectedPrinter;

  const RemovePrinterUseCase({
    required SavedPrintersRepository savedPrinters,
    required GetSelectedPrinterUseCase getSelectedPrinter,
    required ClearSelectedPrinterUseCase clearSelectedPrinter,
  })  : _savedPrinters = savedPrinters,
        _getSelectedPrinter = getSelectedPrinter,
        _clearSelectedPrinter = clearSelectedPrinter;

  Future<Either<DsPrintFailure, Unit>> call(PrinterDevice device) async {
    final removeResult = await _savedPrinters.remove(device);
    if (removeResult.isLeft()) return removeResult;
    final selectedResult = await _getSelectedPrinter();
    return selectedResult.fold(
      (failure) async => Left(failure),
      (selected) async => selected == device
          ? _clearSelectedPrinter()
          : const Right<DsPrintFailure, Unit>(unit),
    );
  }
}
