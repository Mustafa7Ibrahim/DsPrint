import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';

abstract class PrinterDiscoveryRepository {
  Stream<Either<DsPrintFailure, PrinterDevice>> watchDiscoveredDevices();

  Future<Either<DsPrintFailure, List<PrinterDevice>>> discoverOnce();
}
