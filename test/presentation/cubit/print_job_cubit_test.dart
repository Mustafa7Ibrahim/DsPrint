import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ds_print/src/core/error/ds_print_failure.dart';
import 'package:ds_print/src/core/value/paper_width.dart';
import 'package:ds_print/src/domain/entities/print_job.dart';
import 'package:ds_print/src/domain/entities/print_payload.dart';
import 'package:ds_print/src/domain/entities/printer_device.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';
import 'package:ds_print/src/domain/usecases/auto_print_usecase.dart';
import 'package:ds_print/src/domain/usecases/print_job_usecase.dart';
import 'package:ds_print/src/presentation/cubit/print_job_cubit.dart';
import 'package:ds_print/src/presentation/cubit/print_job_state.dart';

class MockAutoPrintUseCase extends Mock implements AutoPrintUseCase {}

class MockPrintJobUseCase extends Mock implements PrintJobUseCase {}

void main() {
  late MockAutoPrintUseCase mockAutoPrint;
  late MockPrintJobUseCase mockPrintJob;

  const payload = HtmlPayload('<html>invoice</html>');
  const device =
      PrinterDevice(id: 'device-1', interfaceType: PrinterInterfaceType.usb);

  setUpAll(() {
    registerFallbackValue(payload);
    registerFallbackValue(
      const PrintJob(
          payload: payload, device: device, paperWidth: PaperWidth.html),
    );
  });

  setUp(() {
    mockAutoPrint = MockAutoPrintUseCase();
    mockPrintJob = MockPrintJobUseCase();
  });

  PrintJobCubit buildCubit() =>
      PrintJobCubit(autoPrint: mockAutoPrint, printJob: mockPrintJob);

  blocTest<PrintJobCubit, PrintJobState>(
    'autoPrint emits [InProgress, Completed] on success',
    setUp: () {
      when(() => mockAutoPrint(any(), copies: any(named: 'copies')))
          .thenAnswer((_) async => const Right(unit));
    },
    build: buildCubit,
    act: (cubit) => cubit.autoPrint(payload),
    expect: () => const [PrintJobInProgress(), PrintJobCompleted()],
  );

  blocTest<PrintJobCubit, PrintJobState>(
    'autoPrint emits [InProgress, Failure] on failure',
    setUp: () {
      when(() => mockAutoPrint(any(), copies: any(named: 'copies'))).thenAnswer(
          (_) async => const Left(NativePrintFailure('native crash')));
    },
    build: buildCubit,
    act: (cubit) => cubit.autoPrint(payload),
    expect: () => const [
      PrintJobInProgress(),
      PrintJobFailure(NativePrintFailure('native crash')),
    ],
  );

  blocTest<PrintJobCubit, PrintJobState>(
    'the re-entry guard: calling autoPrint while already InProgress emits nothing further',
    build: buildCubit,
    seed: () => const PrintJobInProgress(),
    act: (cubit) => cubit.autoPrint(payload),
    expect: () => const <PrintJobState>[],
    verify: (_) {
      verifyNever(() => mockAutoPrint(any(), copies: any(named: 'copies')));
    },
  );

  blocTest<PrintJobCubit, PrintJobState>(
    'printTo emits [InProgress, Completed] on success',
    setUp: () {
      when(() => mockPrintJob(any()))
          .thenAnswer((_) async => const Right(unit));
    },
    build: buildCubit,
    act: (cubit) => cubit.printTo(device, payload),
    expect: () => const [PrintJobInProgress(), PrintJobCompleted()],
  );

  blocTest<PrintJobCubit, PrintJobState>(
    'printTo emits [InProgress, Failure] on failure',
    setUp: () {
      when(() => mockPrintJob(any()))
          .thenAnswer((_) async => const Left(NoPrinterSelectedFailure()));
    },
    build: buildCubit,
    act: (cubit) => cubit.printTo(device, payload),
    expect: () => const [
      PrintJobInProgress(),
      PrintJobFailure(NoPrinterSelectedFailure()),
    ],
  );
}
