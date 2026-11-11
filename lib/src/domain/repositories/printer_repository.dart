import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/print_job.dart';
import '../entities/printer_device.dart';

abstract class PrinterRepository {
  Future<Either<DsPrintFailure, Unit>> print(PrintJob job);

  /// `Right(false)` means the printer did not answer within [timeout].
  /// Serialized with [print] so a check never competes with a running job.
  Future<Either<DsPrintFailure, bool>> checkConnection(
      PrinterDevice device, Duration timeout);
}
