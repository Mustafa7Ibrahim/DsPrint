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

class MockGetSelectedPrinterUseCase extends Mock
    implements GetSelectedPrinterUseCase {}

class MockPrintJobUseCase extends Mock implements PrintJobUseCase {}

void main() {
  late MockGetSelectedPrinterUseCase mockGetSelectedPrinter;
  late MockPrintJobUseCase mockPrintJob;
  late AutoPrintUseCase useCase;

  const payload = HtmlPayload('<html>invoice</html>');
  const validDevice =
      PrinterDevice(id: 'device-1', interfaceType: PrinterInterfaceType.usb);
  const invalidDevice =
      PrinterDevice(id: '', interfaceType: PrinterInterfaceType.usb);

  setUpAll(() {
    // Fallback values for any()/captureAny() matchers - real instances,
    // since PrintPayload/PrintJob can't be Fake-subclassed from outside
    // their own library (PrintPayload is sealed, its leaves are final).
    registerFallbackValue(payload);
    registerFallbackValue(
      const PrintJob(
          payload: payload, device: validDevice, paperWidth: PaperWidth.html),
    );
    registerFallbackValue(validDevice);
  });

  setUp(() {
    mockGetSelectedPrinter = MockGetSelectedPrinterUseCase();
    mockPrintJob = MockPrintJobUseCase();
    // The resolver is real, not mocked, so device resolution is exercised
    // end to end against the selected-printer mock.
    useCase = AutoPrintUseCase(
      resolveDevice:
          ResolvePrintDeviceUseCase(getSelectedPrinter: mockGetSelectedPrinter),
      printJob: mockPrintJob,
    );
  });

  test('empty payload -> Left(EmptyPayloadFailure), nothing else called',
      () async {
    final result = await useCase(const HtmlPayload(''));

    expect(result, const Left<DsPrintFailure, Unit>(EmptyPayloadFailure()));
    verifyNever(() => mockGetSelectedPrinter());
    verifyNever(() => mockPrintJob(any()));
  });

  test('prints to the selected printer', () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(validDevice));
    when(() => mockPrintJob(any())).thenAnswer((_) async => const Right(unit));

    final result = await useCase(payload);

    expect(result, const Right<DsPrintFailure, Unit>(unit));
    final captured = verify(() => mockPrintJob(captureAny())).captured;
    expect((captured.single as PrintJob).device, validDevice);
  });

  test(
      'each interface type is printed to as selected — a selected LAN or '
      'Bluetooth printer is never swapped for another', () async {
    for (final selected in const [
      PrinterDevice(
          id: '192.168.1.50', interfaceType: PrinterInterfaceType.lan),
      PrinterDevice(
          id: '00:11:62:AA:BB:CC',
          interfaceType: PrinterInterfaceType.bluetooth),
      PrinterDevice(id: 'usb-serial', interfaceType: PrinterInterfaceType.usb),
    ]) {
      when(() => mockGetSelectedPrinter())
          .thenAnswer((_) async => Right(selected));
      when(() => mockPrintJob(any()))
          .thenAnswer((_) async => const Right(unit));

      await useCase(payload);

      final captured = verify(() => mockPrintJob(captureAny())).captured;
      expect((captured.single as PrintJob).device, selected);
    }
  });

  test(
      'no selected printer -> Left(NoPrinterSelectedFailure) and nothing is '
      'printed (pairing is manual: there is no discovery fallback)', () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(null));

    final result = await useCase(payload);

    expect(
        result, const Left<DsPrintFailure, Unit>(NoPrinterSelectedFailure()));
    verifyNever(() => mockPrintJob(any()));
  });

  test('an invalid selected printer (empty id) is treated as none', () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(invalidDevice));

    final result = await useCase(payload);

    expect(
        result, const Left<DsPrintFailure, Unit>(NoPrinterSelectedFailure()));
    verifyNever(() => mockPrintJob(any()));
  });

  test('a failed read of the selection propagates as-is', () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Left(StorageFailure('read failed')));

    final result = await useCase(payload);

    expect(result,
        const Left<DsPrintFailure, Unit>(StorageFailure('read failed')));
    verifyNever(() => mockPrintJob(any()));
  });

  test('a native print failure propagates, and the selection is kept',
      () async {
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(validDevice));
    when(() => mockPrintJob(any())).thenAnswer(
        (_) async => const Left(NativePrintFailure('native crash')));

    final result = await useCase(payload);

    expect(result,
        const Left<DsPrintFailure, Unit>(NativePrintFailure('native crash')));
    // AutoPrintUseCase has no way to clear the selection any more; the next
    // print still resolves to the same printer.
    when(() => mockPrintJob(any())).thenAnswer((_) async => const Right(unit));
    expect(await useCase(payload), const Right<DsPrintFailure, Unit>(unit));
    final captured = verify(() => mockPrintJob(captureAny())).captured;
    expect((captured.last as PrintJob).device, validDevice);
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
