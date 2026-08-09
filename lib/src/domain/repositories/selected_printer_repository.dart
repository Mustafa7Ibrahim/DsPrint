import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';

abstract class SelectedPrinterRepository {
  Future<Either<DsPrintFailure, PrinterDevice?>> read();

  Future<Either<DsPrintFailure, Unit>> save(PrinterDevice device);

  Future<Either<DsPrintFailure, Unit>> clear();
}
