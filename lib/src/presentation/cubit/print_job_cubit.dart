import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/print_job.dart';
import '../../domain/entities/print_payload.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/usecases/auto_print_usecase.dart';
import '../../domain/usecases/print_job_usecase.dart';
import 'print_job_state.dart';

class PrintJobCubit extends Cubit<PrintJobState> {
  final AutoPrintUseCase _autoPrint;
  final PrintJobUseCase _printJob;

  PrintJobCubit({
    required AutoPrintUseCase autoPrint,
    required PrintJobUseCase printJob,
  })  : _autoPrint = autoPrint,
        _printJob = printJob,
        super(const PrintJobIdle());

  Future<void> autoPrint(PrintPayload payload, {int copies = 1}) async {
    // Re-entry guard: a second call while a job is already running must not
    // fire a duplicate print job (and duplicate physical receipt).
    if (state is PrintJobInProgress) return;
    emit(const PrintJobInProgress());
    final result = await _autoPrint(payload, copies: copies);
    result.fold(
      (failure) => emit(PrintJobFailure(failure)),
      (_) => emit(const PrintJobCompleted()),
    );
  }

  Future<void> printTo(
    PrinterDevice device,
    PrintPayload payload, {
    int copies = 1,
  }) async {
    if (state is PrintJobInProgress) return;
    emit(const PrintJobInProgress());
    final job = PrintJob.forPayload(
      payload: payload,
      device: device,
      copies: copies,
    );
    final result = await _printJob(job);
    result.fold(
      (failure) => emit(PrintJobFailure(failure)),
      (_) => emit(const PrintJobCompleted()),
    );
  }
}
