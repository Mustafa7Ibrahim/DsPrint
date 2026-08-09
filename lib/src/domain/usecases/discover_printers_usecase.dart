import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';
import '../repositories/printer_discovery_repository.dart';

class DiscoverPrintersUseCase {
  final PrinterDiscoveryRepository _repository;

  const DiscoverPrintersUseCase(this._repository);

  Future<Either<DsPrintFailure, List<PrinterDevice>>> call() {
    return _repository.discoverOnce();
  }
}
