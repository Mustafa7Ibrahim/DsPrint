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
import 'package:ds_print/src/domain/usecases/clear_selected_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/discover_printers_usecase.dart';
import 'package:ds_print/src/domain/usecases/get_selected_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/print_job_usecase.dart';
import 'package:ds_print/src/domain/usecases/resolve_print_device_usecase.dart';
import 'package:ds_print/src/domain/usecases/select_printer_usecase.dart';

class MockGetSelectedPrinterUseCase extends Mock
    implements GetSelectedPrinterUseCase {}

class MockSelectPrinterUseCase extends Mock implements SelectPrinterUseCase {}

class MockClearSelectedPrinterUseCase extends Mock
    implements ClearSelectedPrinterUseCase {}

class MockDiscoverPrintersUseCase extends Mock
    implements DiscoverPrintersUseCase {}

class MockPrintJobUseCase extends Mock implements PrintJobUseCase {}

void main() {
  late MockGetSelectedPrinterUseCase mockGetSelectedPrinter;
  late MockSelectPrinterUseCase mockSelectPrinter;
  late MockClearSelectedPrinterUseCase mockClearSelectedPrinter;
  late MockDiscoverPrintersUseCase mockDiscoverPrinters;
  late MockPrintJobUseCase mockPrintJob;
  late AutoPrintUseCase useCase;

  const payload = HtmlPayload('<html>invoice</html>');
  const validDevice =
      PrinterDevice(id: 'device-1', interfaceType: PrinterInterfaceType.usb);
  const invalidDevice =
      PrinterDevice(id: '', interfaceType: PrinterInterfaceType.usb);
  const device2 =
      PrinterDevice(id: 'device-2', interfaceType: PrinterInterfaceType.lan);

  setUpAll(() {
    // Fallback values for any()/captureAny() matchers - real instances,
    // since PrintPayload/PrintJob can't be Fake-subclassed from outside
    // their own library (PrintPayload is sealed, its leaves are final).
    registerFallbackValue(payload);
    registerFallbackValue(
      PrintJob(
          payload: payload, device: validDevice, paperWidth: PaperWidth.html),
    );
    registerFallbackValue(validDevice);
  });

  setUp(() {
    mockGetSelectedPrinter = MockGetSelectedPrinterUseCase();
    mockSelectPrinter = MockSelectPrinterUseCase();
    mockClearSelectedPrinter = MockClearSelectedPrinterUseCase();
    mockDiscoverPrinters = MockDiscoverPrintersUseCase();
    mockPrintJob = MockPrintJobUseCase();
    // The resolver is real, not mocked, so every device-resolution
    // expectation below still runs against the same three mocks it always
    // did — the extraction into ResolvePrintDeviceUseCase moved that logic
    // without changing it.
    useCase = AutoPrintUseCase(
      resolveDevice: ResolvePrintDeviceUseCase(
        getSelectedPrinter: mockGetSelectedPrinter,
        selectPrinter: mockSelectPrinter,
        discoverPrinters: mockDiscoverPrinters,
      ),
      clearSelectedPrinter: mockClearSelectedPrinter,
      printJob: mockPrintJob,
    );
  });

  test('empty payload -> Left(EmptyPayloadFailure), nothing else called',
      () async {
    final result = await useCase(const HtmlPayload(''));

    expect(result, const Left<DsPrintFailure, Unit>(EmptyPayloadFailure()));
    verifyNever(() => mockGetSelectedPrinter());
    verifyNever(() => mockDiscoverPrinters());
    verifyNever(() => mockSelectPrinter(any()));
    verifyNever(() => mockPrintJob(any()));
    verifyNever(() => mockClearSelectedPrinter());
  });

  test('a valid cached device prints to it - discovery never runs', () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(validDevice));
    when(() => mockPrintJob(any())).thenAnswer((_) async => const Right(unit));

    final result = await useCase(payload);

    expect(result, const Right<DsPrintFailure, Unit>(unit));
    verifyNever(() => mockDiscoverPrinters());
    verify(() => mockPrintJob(any())).called(1);
  });

  test(
      'no cached device discovers, persists the first device, and prints to it',
      () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(null));
    when(() => mockDiscoverPrinters())
        .thenAnswer((_) async => const Right([validDevice, device2]));
    when(() => mockSelectPrinter(any()))
        .thenAnswer((_) async => const Right(unit));
    when(() => mockPrintJob(any())).thenAnswer((_) async => const Right(unit));

    final result = await useCase(payload);

    expect(result, const Right<DsPrintFailure, Unit>(unit));
    verify(() => mockSelectPrinter(validDevice)).called(1);
    final captured = verify(() => mockPrintJob(captureAny())).captured;
    expect((captured.single as PrintJob).device, validDevice);
  });

  test('an invalid cached device (empty id) also triggers discovery', () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(invalidDevice));
    when(() => mockDiscoverPrinters())
        .thenAnswer((_) async => const Right([validDevice]));
    when(() => mockSelectPrinter(any()))
        .thenAnswer((_) async => const Right(unit));
    when(() => mockPrintJob(any())).thenAnswer((_) async => const Right(unit));

    final result = await useCase(payload);

    expect(result, const Right<DsPrintFailure, Unit>(unit));
    verify(() => mockDiscoverPrinters()).called(1);
  });

  test('discovery returns empty -> Left(NoDeviceFoundFailure)', () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(null));
    when(() => mockDiscoverPrinters())
        .thenAnswer((_) async => const Right(<PrinterDevice>[]));

    final result = await useCase(payload);

    expect(result, const Left<DsPrintFailure, Unit>(NoDeviceFoundFailure()));
    verifyNever(() => mockSelectPrinter(any()));
    verifyNever(() => mockPrintJob(any()));
  });

  test(
      'print returns Left(NativePrintFailure) -> ClearSelectedPrinterUseCase is called, Left propagates',
      () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(validDevice));
    when(() => mockPrintJob(any())).thenAnswer(
        (_) async => const Left(NativePrintFailure('native crash')));
    when(() => mockClearSelectedPrinter())
        .thenAnswer((_) async => const Right(unit));

    final result = await useCase(payload);

    expect(result,
        const Left<DsPrintFailure, Unit>(NativePrintFailure('native crash')));
    verify(() => mockClearSelectedPrinter()).called(1);
  });

  test('print returns a different failure -> the cache is NOT cleared',
      () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(validDevice));
    when(() => mockPrintJob(any()))
        .thenAnswer((_) async => const Left(NoPrinterSelectedFailure()));

    final result = await useCase(payload);

    expect(
        result, const Left<DsPrintFailure, Unit>(NoPrinterSelectedFailure()));
    verifyNever(() => mockClearSelectedPrinter());
  });

  test('copies is threaded into the PrintJob', () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(validDevice));
    when(() => mockPrintJob(any())).thenAnswer((_) async => const Right(unit));

    await useCase(payload, copies: 3);

    final captured = verify(() => mockPrintJob(captureAny())).captured;
    expect((captured.single as PrintJob).copies, 3);
  });
}
