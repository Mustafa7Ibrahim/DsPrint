import 'package:dartz/dartz.dart';

import '../../core/config/ds_print_config.dart';
import '../../core/error/ds_print_failure.dart';
import '../entities/printer_device.dart';
import '../entities/printer_interface_type.dart';
import '../repositories/printer_repository.dart';

/// Asks whether [PrinterDevice] answers a short connection attempt.
/// `Right(false)` is "not reachable"; a `Left` means the check itself failed.
class CheckPrinterConnectionUseCase {
  final PrinterRepository _repository;

  const CheckPrinterConnectionUseCase(this._repository);

  /// Bluetooth is slower to connect; USB and LAN answer (or don't) quickly.
  static Duration defaultTimeoutFor(PrinterInterfaceType type) =>
      switch (type) {
        PrinterInterfaceType.bluetooth => const Duration(seconds: 5),
        PrinterInterfaceType.usb ||
        PrinterInterfaceType.lan =>
          const Duration(seconds: 3),
      };

  Future<Either<DsPrintFailure, bool>> call(PrinterDevice device) async {
    if (!device.isValid) {
      return const Left(NoPrinterSelectedFailure());
    }
    final timeout = DsPrintConfig.current?.connectionCheckTimeout ??
        defaultTimeoutFor(device.interfaceType);
    return _repository.checkConnection(device, timeout);
  }
}
