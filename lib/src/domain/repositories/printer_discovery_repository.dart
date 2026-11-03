import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';
import '../entities/printer_interface_type.dart';

/// [interfaceType] restricts discovery to one connection type; `null` scans
/// the legacy default of USB + LAN.
abstract class PrinterDiscoveryRepository {
  Stream<Either<DsPrintFailure, PrinterDevice>> watchDiscoveredDevices({
    PrinterInterfaceType? interfaceType,
  });

  Future<Either<DsPrintFailure, List<PrinterDevice>>> discoverOnce({
    PrinterInterfaceType? interfaceType,
  });
}
