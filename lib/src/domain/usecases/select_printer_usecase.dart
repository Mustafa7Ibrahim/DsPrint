import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';
import '../repositories/selected_printer_repository.dart';

class SelectPrinterUseCase {
  final SelectedPrinterRepository _repository;

  const SelectPrinterUseCase(this._repository);

  Future<Either<DsPrintFailure, Unit>> call(PrinterDevice device) {
    return _repository.save(device);
  }
}
