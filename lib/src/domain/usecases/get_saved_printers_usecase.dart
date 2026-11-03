import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';
import '../repositories/saved_printers_repository.dart';

class GetSavedPrintersUseCase {
  final SavedPrintersRepository _repository;

  const GetSavedPrintersUseCase(this._repository);

  Future<Either<DsPrintFailure, List<PrinterDevice>>> call() {
    return _repository.readAll();
  }
}
