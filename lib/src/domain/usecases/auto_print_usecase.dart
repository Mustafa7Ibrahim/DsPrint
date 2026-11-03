import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/print_job.dart';
import '../entities/print_payload.dart';
import 'print_job_usecase.dart';
import 'resolve_print_device_usecase.dart';

/// Prints [PrintPayload] to the printer the user selected, or fails with
/// [NoPrinterSelectedFailure] when none is selected.
///
/// A native print failure no longer drops the selection. That legacy
/// behaviour only made sense while the next print would rediscover a printer
/// on its own; with manual pairing it would mean one print to a printer that
/// was briefly switched off silently stops every later print until the user
/// re-pairs.
class AutoPrintUseCase {
  final ResolvePrintDeviceUseCase _resolveDevice;
  final PrintJobUseCase _printJob;

  const AutoPrintUseCase({
    required ResolvePrintDeviceUseCase resolveDevice,
    required PrintJobUseCase printJob,
  })  : _resolveDevice = resolveDevice,
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
      (device) => _printJob(
        PrintJob.forPayload(payload: payload, device: device, copies: copies),
      ),
    );
  }
}
