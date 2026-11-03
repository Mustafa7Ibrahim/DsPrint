import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';
import '../repositories/saved_printers_repository.dart';
import 'select_printer_usecase.dart';

/// Saves [PrinterDevice] to the user's printer list and makes it the active
/// printer — the one every later print call goes to. Re-adding a printer that
/// is already saved just re-activates it.
class AddPrinterUseCase {
  final SavedPrintersRepository _savedPrinters;
  final SelectPrinterUseCase _selectPrinter;

  const AddPrinterUseCase({
    required SavedPrintersRepository savedPrinters,
    required SelectPrinterUseCase selectPrinter,
  })  : _savedPrinters = savedPrinters,
        _selectPrinter = selectPrinter;

  Future<Either<DsPrintFailure, Unit>> call(PrinterDevice device) async {
    if (!device.isValid) return const Left(NoPrinterSelectedFailure());
    final addResult = await _savedPrinters.add(device);
    return addResult.fold(
      (failure) async => Left(failure),
      (_) => _selectPrinter(device),
    );
  }
}
