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
import 'package:ds_print/src/domain/usecases/get_selected_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/print_job_usecase.dart';
import 'package:ds_print/src/domain/usecases/resolve_print_device_usecase.dart';
import 'package:ds_print/src/presentation/cubit/print_job_cubit.dart';
import 'package:ds_print/src/presentation/cubit/print_job_state.dart';

class MockAutoPrintUseCase extends Mock implements AutoPrintUseCase {}

class MockPrintJobUseCase extends Mock implements PrintJobUseCase {}

class MockGetSelectedPrinterUseCase extends Mock
    implements GetSelectedPrinterUseCase {}

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

  // InvoicePreviewScreen's Print button calls autoPrint and opens the picker
  // only on NoPrinterSelectedFailure. These pin both sides of that signal
  // with the real AutoPrintUseCase / ResolvePrintDeviceUseCase.
  group('autoPrint through the real use cases (the preview Print button)', () {
    late MockGetSelectedPrinterUseCase getSelected;

    setUp(() => getSelected = MockGetSelectedPrinterUseCase());

    PrintJobCubit buildRealCubit() => PrintJobCubit(
          autoPrint: AutoPrintUseCase(
            resolveDevice:
                ResolvePrintDeviceUseCase(getSelectedPrinter: getSelected),
            printJob: mockPrintJob,
          ),
          printJob: mockPrintJob,
        );

    blocTest<PrintJobCubit, PrintJobState>(
      'a selected printer is printed to directly — no picker',
      setUp: () {
        when(() => getSelected()).thenAnswer((_) async => const Right(device));
        when(() => mockPrintJob(any()))
            .thenAnswer((_) async => const Right(unit));
      },
      build: buildRealCubit,
      act: (cubit) => cubit.autoPrint(payload),
      expect: () => const [PrintJobInProgress(), PrintJobCompleted()],
      verify: (_) {
        final job = verify(() => mockPrintJob(captureAny())).captured.single
            as PrintJob;
        expect(job.device, device);
      },
    );

    blocTest<PrintJobCubit, PrintJobState>(
      'nothing selected fails with NoPrinterSelectedFailure — the signal '
      'that opens the picker',
      setUp: () =>
          when(() => getSelected()).thenAnswer((_) async => const Right(null)),
      build: buildRealCubit,
      act: (cubit) => cubit.autoPrint(payload),
      expect: () => const [
        PrintJobInProgress(),
        PrintJobFailure(NoPrinterSelectedFailure()),
      ],
      verify: (_) => verifyNever(() => mockPrintJob(any())),
    );
  });
}
