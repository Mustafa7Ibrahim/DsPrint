import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';

abstract class SavedPrintersRepository {
  Future<Either<DsPrintFailure, List<PrinterDevice>>> readAll();

  Future<Either<DsPrintFailure, Unit>> add(PrinterDevice device);

  Future<Either<DsPrintFailure, Unit>> remove(PrinterDevice device);
}
