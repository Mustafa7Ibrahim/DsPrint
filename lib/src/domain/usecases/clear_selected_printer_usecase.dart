import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../repositories/selected_printer_repository.dart';

class ClearSelectedPrinterUseCase {
  final SelectedPrinterRepository _repository;

  const ClearSelectedPrinterUseCase(this._repository);

  Future<Either<DsPrintFailure, Unit>> call() {
    return _repository.clear();
  }
}
