import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';
import 'get_selected_printer_usecase.dart';

/// Answers "which device should this print go to?": the printer the user
/// selected, or [NoPrinterSelectedFailure] when there is none.
///
/// Pairing is manual. This deliberately never runs discovery: a print must
/// not land on whichever printer a scan happens to turn up first — it goes to
/// the printer the user chose, or nowhere.
///
/// Split out of [AutoPrintUseCase] so a caller can find out whether a printer
/// is selected *before* paying for the work that only makes sense if one is.
/// The silent path renders the invoice in a WebView behind a blocking scrim;
/// doing that for a store with no printer froze the app and printed nothing.
class ResolvePrintDeviceUseCase {
  final GetSelectedPrinterUseCase _getSelectedPrinter;

  const ResolvePrintDeviceUseCase({
    required GetSelectedPrinterUseCase getSelectedPrinter,
  }) : _getSelectedPrinter = getSelectedPrinter;

  Future<Either<DsPrintFailure, PrinterDevice>> call() async {
    final selectedResult = await _getSelectedPrinter();
    return selectedResult.fold(
      (failure) => Left(failure),
      (selected) => selected != null && selected.isValid
          ? Right(selected)
          : const Left(NoPrinterSelectedFailure()),
    );
  }
}
