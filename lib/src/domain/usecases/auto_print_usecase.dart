import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/print_job.dart';
import '../entities/print_payload.dart';
import '../entities/printer_device.dart';
import 'clear_selected_printer_usecase.dart';
import 'discover_printers_usecase.dart';
import 'get_selected_printer_usecase.dart';
import 'print_job_usecase.dart';
import 'select_printer_usecase.dart';

/// Replicates the legacy
/// `PrinterCubit.printOnDiscoverFirstDeviceOrGetFromDeviceIdFromCacheThenAutoPrint`
/// flow: prefer the cached device, else discover-and-persist-first, else fail.
class AutoPrintUseCase {
  final GetSelectedPrinterUseCase _getSelectedPrinter;
  final SelectPrinterUseCase _selectPrinter;
  final ClearSelectedPrinterUseCase _clearSelectedPrinter;
  final DiscoverPrintersUseCase _discoverPrinters;
  final PrintJobUseCase _printJob;

  const AutoPrintUseCase({
    required GetSelectedPrinterUseCase getSelectedPrinter,
    required SelectPrinterUseCase selectPrinter,
    required ClearSelectedPrinterUseCase clearSelectedPrinter,
    required DiscoverPrintersUseCase discoverPrinters,
    required PrintJobUseCase printJob,
  })  : _getSelectedPrinter = getSelectedPrinter,
        _selectPrinter = selectPrinter,
        _clearSelectedPrinter = clearSelectedPrinter,
        _discoverPrinters = discoverPrinters,
        _printJob = printJob;

  Future<Either<DsPrintFailure, Unit>> call(
    PrintPayload payload, {
    int copies = 1,
  }) async {
    if (payload.isEmpty) {
      return const Left(EmptyPayloadFailure());
    }

    final deviceResult = await _resolveDevice();
    return deviceResult.fold(
      (failure) async => Left(failure),
      (device) => _printAndClearCacheOnNativeFailure(payload, device, copies),
    );
  }

  Future<Either<DsPrintFailure, Unit>> _printAndClearCacheOnNativeFailure(
    PrintPayload payload,
    PrinterDevice device,
    int copies,
  ) async {
    final job = PrintJob.forPayload(
      payload: payload,
      device: device,
      copies: copies,
    );
    final printResult = await _printJob(job);
    return printResult.fold(
      (failure) async {
        // Preserves the legacy behaviour: a device that just failed to print
        // natively is dropped from the cache instead of being retried forever.
        if (failure is NativePrintFailure) {
          await _clearSelectedPrinter();
        }
        return Left(failure);
      },
      (_) async => const Right(unit),
    );
  }

  Future<Either<DsPrintFailure, PrinterDevice>> _resolveDevice() async {
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
