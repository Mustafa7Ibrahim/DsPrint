// Widget tests for PrinterPickerScreen only. InvoicePreviewScreen and
// DsPrintWebSurface are intentionally NOT covered here: both need a
// WebViewPlatform implementation to pump (no in-memory fake exists for
// webview_flutter in this package), and the algorithm that actually matters
// - the capture pipeline - is already covered directly and thoroughly by
// capture_height_resolver_test.dart and invoice_capture_runner_test.dart
// against DsWebController/DsImageBoundary fakes. A widget-level smoke test
// of those two screens would mostly be re-testing webview_flutter itself.
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ds_print/src/core/di/ds_print_injection.dart';
import 'package:ds_print/src/core/error/ds_print_failure.dart';
import 'package:ds_print/src/core/value/paper_width.dart';
import 'package:ds_print/src/domain/entities/print_job.dart';
import 'package:ds_print/src/domain/entities/print_payload.dart';
import 'package:ds_print/src/domain/entities/printer_device.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';
import 'package:ds_print/src/domain/usecases/auto_print_usecase.dart';
import 'package:ds_print/src/domain/usecases/discover_printers_usecase.dart';
import 'package:ds_print/src/domain/usecases/get_selected_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/print_job_usecase.dart';
import 'package:ds_print/src/domain/usecases/select_printer_usecase.dart';
import 'package:ds_print/src/presentation/cubit/print_job_cubit.dart';
import 'package:ds_print/src/presentation/cubit/printer_discovery_cubit.dart';
import 'package:ds_print/src/presentation/screens/printer_picker_screen.dart';
import 'package:ds_print/src/presentation/widgets/ds_print_message_dialog.dart';
import 'package:ds_print/src/presentation/widgets/printer_device_tile.dart';

class MockDiscoverPrintersUseCase extends Mock
    implements DiscoverPrintersUseCase {}

class MockGetSelectedPrinterUseCase extends Mock
    implements GetSelectedPrinterUseCase {}

class MockSelectPrinterUseCase extends Mock implements SelectPrinterUseCase {}

class MockAutoPrintUseCase extends Mock implements AutoPrintUseCase {}

class MockPrintJobUseCase extends Mock implements PrintJobUseCase {}

void main() {
  late MockDiscoverPrintersUseCase mockDiscoverPrinters;
  late MockGetSelectedPrinterUseCase mockGetSelectedPrinter;
  late MockSelectPrinterUseCase mockSelectPrinter;
  late MockAutoPrintUseCase mockAutoPrint;
  late MockPrintJobUseCase mockPrintJob;

  const device1 =
      PrinterDevice(id: 'device-1', interfaceType: PrinterInterfaceType.usb);
  const device2 =
      PrinterDevice(id: 'device-2', interfaceType: PrinterInterfaceType.lan);
  const device3 = PrinterDevice(
      id: 'device-3', interfaceType: PrinterInterfaceType.bluetooth);

  setUpAll(() {
    registerFallbackValue(device1);
    registerFallbackValue(const HtmlPayload('fallback'));
    registerFallbackValue(
      const PrintJob(
        payload: HtmlPayload('fallback'),
        device: device1,
        paperWidth: PaperWidth.html,
      ),
    );
  });

  setUp(() {
    mockDiscoverPrinters = MockDiscoverPrintersUseCase();
    mockGetSelectedPrinter = MockGetSelectedPrinterUseCase();
    mockSelectPrinter = MockSelectPrinterUseCase();
    mockAutoPrint = MockAutoPrintUseCase();
    mockPrintJob = MockPrintJobUseCase();

    // The screen resolves its cubits through dsPrintResolve, which calls
    // dsPrintInjection() first; registering real cubits backed by
    // mocktail-mocked use cases here exercises the actual
    // PrinterDiscoveryCubit/PrintJobCubit logic, not a hand-rolled
    // stand-in. Also register AutoPrintUseCase — dsPrintInjection()'s
    // sentinel check — so it short-circuits instead of trying (and failing,
    // since GetIt disallows re-registration) to register real cubits over
    // these mocked ones.
    dsPrintSl.reset();
    dsPrintSl.registerFactory<AutoPrintUseCase>(() => mockAutoPrint);
    dsPrintSl.registerFactory<PrinterDiscoveryCubit>(
      () => PrinterDiscoveryCubit(
        discoverPrinters: mockDiscoverPrinters,
        getSelectedPrinter: mockGetSelectedPrinter,
        selectPrinter: mockSelectPrinter,
      ),
    );
    dsPrintSl.registerFactory<PrintJobCubit>(
      () => PrintJobCubit(autoPrint: mockAutoPrint, printJob: mockPrintJob),
    );
  });

  tearDown(() => dsPrintSl.reset());

  testWidgets('an empty device list renders the Add Printer button',
      (tester) async {
    when(() => mockDiscoverPrinters())
        .thenAnswer((_) async => const Right(<PrinterDevice>[]));
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(null));

    await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(AddPrinterButton), findsOneWidget);
    expect(find.byType(PrinterDeviceTile), findsNothing);
  });

  testWidgets('three devices render three PrinterDeviceTiles', (tester) async {
    when(() => mockDiscoverPrinters())
        .thenAnswer((_) async => const Right([device1, device2, device3]));
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(null));

    await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(PrinterDeviceTile), findsNWidgets(3));
  });

  testWidgets('tapping a tile calls select with that device', (tester) async {
    when(() => mockDiscoverPrinters())
        .thenAnswer((_) async => const Right([device1, device2]));
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(null));
    when(() => mockSelectPrinter(any()))
        .thenAnswer((_) async => const Right(unit));

    await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PrinterDeviceTile).first);
    await tester.pumpAndSettle();

    verify(() => mockSelectPrinter(device1)).called(1);
  });

  testWidgets('a PrintJobFailure shows DsPrintMessageDialog, never a SnackBar',
      (tester) async {
    when(() => mockDiscoverPrinters())
        .thenAnswer((_) async => const Right([device1]));
    when(() => mockGetSelectedPrinter())
        .thenAnswer((_) async => const Right(null));
    when(() => mockSelectPrinter(any()))
        .thenAnswer((_) async => const Right(unit));
    when(() => mockPrintJob(any())).thenAnswer(
        (_) async => const Left(NativePrintFailure('native crash')));

    await tester.pumpWidget(
      const MaterialApp(
        home: PrinterPickerScreen(payload: HtmlPayload('<html></html>')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PrinterDeviceTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(DsPrintMessageDialog), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'builds on a completely empty container — no manual registration '
    '(regression for "InvoicePreviewCubit is not registered inside GetIt", '
    'reproduced via PrinterPickerScreen since InvoicePreviewScreen builds a '
    'WebViewController and needs a WebViewPlatform implementation this '
    'package has no in-memory fake for)',
    (tester) async {
      // Undo the mocked registrations `setUp` just made above, so this test
      // exercises the real dsPrintInjection() path the way a host app's
      // router hitting this screen directly would.
      await dsPrintSl.reset();

      // Forces the real PrinterDiscoveryDataSource down its "off Android"
      // early-return path (an immediate Stream.error, no MethodChannel /
      // EventChannel round-trip) instead of hanging on a native discovery
      // channel that has no handler registered in a widget test — this test
      // is only about the DI wiring, not a platform-channel integration test.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
