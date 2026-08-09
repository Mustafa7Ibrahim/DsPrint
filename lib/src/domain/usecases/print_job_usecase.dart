import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/print_job.dart';
import '../repositories/printer_repository.dart';

class PrintJobUseCase {
  final PrinterRepository _repository;

  const PrintJobUseCase(this._repository);

  Future<Either<DsPrintFailure, Unit>> call(PrintJob job) {
    if (job.payload.isEmpty) {
      return Future.value(const Left(EmptyPayloadFailure()));
    }
    if (!job.device.isValid) {
      return Future.value(const Left(NoPrinterSelectedFailure()));
    }
    return _repository.print(job);
  }
}
