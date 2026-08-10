import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';
import 'discover_printers_usecase.dart';
import 'get_selected_printer_usecase.dart';
import 'select_printer_usecase.dart';

/// Answers "which device should this print go to?" — the cached one if it is
/// still valid, otherwise the first device discovery turns up, which is then
/// persisted as the pairing. [NoDeviceFoundFailure] when there is no printer.
///
/// Split out of [AutoPrintUseCase] so a caller can find out whether a printer
/// exists *before* paying for the work that only makes sense if one does. The
/// silent path renders the invoice in a WebView behind a blocking scrim, and
/// discovery costs up to ten seconds: doing both for a store that has no
/// printer froze the app for no reason and printed nothing.
///
/// Calling this and then letting [AutoPrintUseCase] resolve again is not a
/// double cost. Resolution is idempotent and persists what it finds, so the
/// second pass is a cached read — never a second discovery scan.
class ResolvePrintDeviceUseCase {
  final GetSelectedPrinterUseCase _getSelectedPrinter;
  final SelectPrinterUseCase _selectPrinter;
  final DiscoverPrintersUseCase _discoverPrinters;

  const ResolvePrintDeviceUseCase({
    required GetSelectedPrinterUseCase getSelectedPrinter,
    required SelectPrinterUseCase selectPrinter,
    required DiscoverPrintersUseCase discoverPrinters,
  })  : _getSelectedPrinter = getSelectedPrinter,
        _selectPrinter = selectPrinter,
        _discoverPrinters = discoverPrinters;

  Future<Either<DsPrintFailure, PrinterDevice>> call() async {
    final selectedResult = await _getSelectedPrinter();
    return selectedResult.fold(
      (failure) async => Left(failure),
      (selected) async {
        if (selected != null && selected.isValid) {
          return Right(selected);
        }
        return _discoverAndPersistFirstDevice();
      },
    );
  }

  Future<Either<DsPrintFailure, PrinterDevice>>
      _discoverAndPersistFirstDevice() async {
    final discoveredResult = await _discoverPrinters();
    return discoveredResult.fold(
      (failure) async => Left(failure),
      (devices) async {
        if (devices.isEmpty) {
          return const Left(NoDeviceFoundFailure());
        }
        final firstDevice = devices.first;
        final saveResult = await _selectPrinter(firstDevice);
        return saveResult.fold(
          (failure) => Left(failure),
          (_) => Right(firstDevice),
        );
      },
    );
  }
}
