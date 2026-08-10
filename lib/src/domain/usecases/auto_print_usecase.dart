import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/print_job.dart';
import '../entities/print_payload.dart';
import '../entities/printer_device.dart';
import 'clear_selected_printer_usecase.dart';
import 'print_job_usecase.dart';
import 'resolve_print_device_usecase.dart';

/// Replicates the legacy
/// `PrinterCubit.printOnDiscoverFirstDeviceOrGetFromDeviceIdFromCacheThenAutoPrint`
/// flow: prefer the cached device, else discover-and-persist-first, else fail.
///
/// Device resolution itself lives in [ResolvePrintDeviceUseCase] so callers
/// that need to know whether a printer exists — before rendering an invoice
/// for one — can ask without printing anything.
class AutoPrintUseCase {
  final ResolvePrintDeviceUseCase _resolveDevice;
  final ClearSelectedPrinterUseCase _clearSelectedPrinter;
  final PrintJobUseCase _printJob;

  const AutoPrintUseCase({
    required ResolvePrintDeviceUseCase resolveDevice,
    required ClearSelectedPrinterUseCase clearSelectedPrinter,
    required PrintJobUseCase printJob,
  })  : _resolveDevice = resolveDevice,
        _clearSelectedPrinter = clearSelectedPrinter,
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
}
