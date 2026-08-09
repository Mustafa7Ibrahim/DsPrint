import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/print_job.dart';

abstract class PrinterRepository {
  Future<Either<DsPrintFailure, Unit>> print(PrintJob job);
}
