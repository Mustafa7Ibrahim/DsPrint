import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_exception.dart';
import '../../core/error/ds_print_failure.dart';
import '../../domain/entities/print_job.dart';
import '../../domain/repositories/printer_repository.dart';
import '../datasources/printer_native_datasource.dart';
import '../services/print_job_queue.dart';

class PrinterRepositoryImpl implements PrinterRepository {
  final PrinterNativeDataSource _dataSource;
  final PrintJobQueue _queue;

  const PrinterRepositoryImpl({
    required PrinterNativeDataSource dataSource,
    required PrintJobQueue queue,
  })  : _dataSource = dataSource,
        _queue = queue;

  @override
  Future<Either<DsPrintFailure, Unit>> print(PrintJob job) {
    // Every print goes through the queue so job B never starts mid-job-A.
    return _queue.enqueue(() => _print(job));
  }

  Future<Either<DsPrintFailure, Unit>> _print(PrintJob job) async {
    try {
      await _dataSource.print(job);
      return const Right(unit);
    } on EmptyPayloadException {
      return const Left(EmptyPayloadFailure());
    } on NativePrintException catch (e) {
      return Left(NativePrintFailure(e.details));
    } on DsPrintException catch (e) {
      return Left(NativePrintFailure(e.message));
    } catch (e) {
      return Left(NativePrintFailure(e.toString()));
    }
  }
}
