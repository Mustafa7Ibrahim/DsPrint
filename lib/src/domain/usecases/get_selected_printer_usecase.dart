import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';
import '../repositories/selected_printer_repository.dart';

class GetSelectedPrinterUseCase {
  final SelectedPrinterRepository _repository;

  const GetSelectedPrinterUseCase(this._repository);

  Future<Either<DsPrintFailure, PrinterDevice?>> call() {
    return _repository.read();
  }
}
