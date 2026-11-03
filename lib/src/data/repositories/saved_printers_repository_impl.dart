import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_exception.dart';
import '../../core/error/ds_print_failure.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/repositories/saved_printers_repository.dart';
import '../datasources/saved_printers_datasource.dart';

class SavedPrintersRepositoryImpl implements SavedPrintersRepository {
  final SavedPrintersDataSource _dataSource;

  const SavedPrintersRepositoryImpl(this._dataSource);

  @override
  Future<Either<DsPrintFailure, List<PrinterDevice>>> readAll() =>
      _guard(_dataSource.readAll);

  @override
  Future<Either<DsPrintFailure, Unit>> add(PrinterDevice device) =>
      _guard(() async {
        await _dataSource.add(device);
        return unit;
      });

  @override
  Future<Either<DsPrintFailure, Unit>> remove(PrinterDevice device) =>
      _guard(() async {
        await _dataSource.remove(device);
        return unit;
      });

  Future<Either<DsPrintFailure, T>> _guard<T>(
      Future<T> Function() action) async {
    try {
      return Right(await action());
    } on StorageException catch (e) {
      return Left(StorageFailure(e.details));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
