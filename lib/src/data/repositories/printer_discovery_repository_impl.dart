import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_exception.dart';
import '../../core/error/ds_print_failure.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/entities/printer_interface_type.dart';
import '../../domain/repositories/printer_discovery_repository.dart';
import '../datasources/printer_discovery_datasource.dart';

class PrinterDiscoveryRepositoryImpl implements PrinterDiscoveryRepository {
  final PrinterDiscoveryDataSource _dataSource;

  const PrinterDiscoveryRepositoryImpl(this._dataSource);

  @override
  Stream<Either<DsPrintFailure, PrinterDevice>> watchDiscoveredDevices({
    PrinterInterfaceType? interfaceType,
  }) async* {
    try {
      await for (final device
          in _dataSource.watch(interfaceType: interfaceType)) {
        yield Right(device);
      }
    } on DsPrintException catch (e) {
      yield Left(_mapException(e));
    } catch (e) {
      yield Left(DiscoveryFailure(e.toString()));
    }
  }

  @override
  Future<Either<DsPrintFailure, List<PrinterDevice>>> discoverOnce({
    PrinterInterfaceType? interfaceType,
  }) async {
    try {
      final devices =
          await _dataSource.discoverOnce(interfaceType: interfaceType);
      return Right(devices);
    } on DsPrintException catch (e) {
      return Left(_mapException(e));
    } catch (e) {
      return Left(DiscoveryFailure(e.toString()));
    }
  }

  DsPrintFailure _mapException(DsPrintException e) => switch (e) {
        EmptyPayloadException() => const EmptyPayloadFailure(),
        NoDeviceFoundException() => const NoDeviceFoundFailure(),
        UnsupportedPlatformException() => const UnsupportedPlatformFailure(),
        CaptureException(:final details) => CaptureFailure(details),
        NativePrintException(:final details) => NativePrintFailure(details),
        StorageException(:final details) => StorageFailure(details),
        PermissionDeniedException() => const PermissionDeniedFailure(),
        InterfaceUnavailableException(:final interfaceType) =>
          InterfaceUnavailableFailure(interfaceType),
        DiscoveryException(:final details) => DiscoveryFailure(details),
      };
}
