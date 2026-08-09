import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_exception.dart';
import '../../core/error/ds_print_failure.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/repositories/selected_printer_repository.dart';
import '../datasources/selected_printer_datasource.dart';

class SelectedPrinterRepositoryImpl implements SelectedPrinterRepository {
  final SelectedPrinterDataSource _dataSource;

  const SelectedPrinterRepositoryImpl(this._dataSource);

  @override
  Future<Either<DsPrintFailure, PrinterDevice?>> read() async {
    try {
      return Right(await _dataSource.read());
    } on StorageException catch (e) {
      return Left(StorageFailure(e.details));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<DsPrintFailure, Unit>> save(PrinterDevice device) async {
    try {
      await _dataSource.save(device);
      return const Right(unit);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.details));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<DsPrintFailure, Unit>> clear() async {
    try {
      await _dataSource.clear();
      return const Right(unit);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.details));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
