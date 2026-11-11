// Widget tests for PrinterPickerScreen, the Add Printer sheet and the public
// DsPrintAddPrinterButton. InvoicePreviewScreen and DsPrintWebSurface are
// intentionally NOT covered here: both need a WebViewPlatform implementation
// to pump (no in-memory fake exists for webview_flutter in this package).
//
// Everything below runs the real DI graph — cubits, use cases, repositories,
// SharedPreferences storage (in-memory) and the real discovery datasource
// talking to a mocked native side of `com.printer.discover/event`. Only the
// final native print call (PrintJobUseCase) is mocked. That makes these the
// end-to-end check of the Bluetooth / LAN flows short of real hardware.
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ds_print/ds_print.dart';
import 'package:ds_print/src/core/di/ds_print_injection.dart';
import 'package:ds_print/src/data/datasources/saved_printers_datasource.dart';
import 'package:ds_print/src/domain/entities/print_job.dart';
import 'package:ds_print/src/domain/usecases/auto_print_usecase.dart';
import 'package:ds_print/src/domain/usecases/check_printer_connection_usecase.dart';
import 'package:ds_print/src/domain/usecases/print_job_usecase.dart';
import 'package:ds_print/src/presentation/widgets/ds_print_add_printer_sheet.dart';
import 'package:ds_print/src/presentation/widgets/ds_print_message_dialog.dart';
import 'package:ds_print/src/presentation/widgets/printer_device_tile.dart';

class MockPrintJobUseCase extends Mock implements PrintJobUseCase {}

class MockCheckConnectionUseCase extends Mock
    implements CheckPrinterConnectionUseCase {}

const _discoveryChannel = EventChannel('com.printer.discover/event');

const _lan =
    PrinterDevice(id: '192.168.1.50', interfaceType: PrinterInterfaceType.lan);
const _bluetooth = PrinterDevice(
    id: '00:11:62:AA:BB:CC', interfaceType: PrinterInterfaceType.bluetooth);
const _usb =
    PrinterDevice(id: 'usb-serial-1', interfaceType: PrinterInterfaceType.usb);

Map<String, String> _nativePrinter(PrinterDevice device) => {
      'name': 'TSP100',
      'id': device.id,
      'interfaceType': device.interfaceType.nativeName,
    };

void main() {
  late MockPrintJobUseCase printJob;

  /// Every `listen` argument the fake native discovery side received.
  late List<Object?> scans;

  /// What fake native discovery reports for each requested type.
  late Map<String?, List<Object?>> nativeReplies;

  setUpAll(() {
    registerFallbackValue(
      const PrintJob(
        payload: HtmlPayload('fallback'),
        device: _usb,
        paperWidth: PaperWidth.html,
      ),
    );
    registerFallbackValue(_usb);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    printJob = MockPrintJobUseCase();
    when(() => printJob(any())).thenAnswer((_) async => const Right(unit));

    scans = [];
    nativeReplies = {};

    // The real graph, with only the native print call swapped out.
    await dsPrintSl.reset();
    dsPrintInjection();
    dsPrintSl.allowReassignment = true;
    dsPrintSl.registerLazySingleton<PrintJobUseCase>(() => printJob);
    // No native side here, so the Printers-screen connection check is faked.
    final checkConnection = MockCheckConnectionUseCase();
    when(() => checkConnection(any()))
        .thenAnswer((_) async => const Right(true));
    dsPrintSl.registerLazySingleton<CheckPrinterConnectionUseCase>(
        () => checkConnection);
    dsPrintSl.allowReassignment = false;
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(_discoveryChannel, null);
    await dsPrintSl.reset();
  });

  /// The fake native side of discovery. Installed from inside each test
  /// body: a handler installed in `setUp` lives outside the widget test's
  /// fake-async zone, and its events would never arrive during `pump`.
  void installFakeNative() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      _discoveryChannel,
      MockStreamHandler.inline(onListen: (argument, events) {
        scans.add(argument);
        for (final reply in nativeReplies[argument] ?? const ['finished']) {
          if (reply is PlatformException) {
            events.error(code: reply.code, message: reply.message);
          } else {
            events.success(reply);
          }
        }
      }),
    );
  }

  /// A widget test with the fake native discovery side installed.
  void nativeTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      installFakeNative();
      await body(tester);
    });
  }

  Future<void> savePrinters(List<PrinterDevice> printers,
      {PrinterDevice? active}) async {
    const saved = SavedPrintersDataSourceImpl();
    for (final printer in printers) {
      await saved.add(printer);
    }
    if (active != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer-deviceId', active.id);
      await prefs.setString(
          'printer-device-interface-type', active.interfaceType.nativeName);
    }
  }

  Future<PrinterDevice?> activePrinter() async =>
      (await DsPrint.selectedPrinter()).getOrElse(() => null);

  Future<List<PrinterDevice>> storedPrinters() async =>
      (await DsPrint.savedPrinters()).getOrElse(() => []);

  /// Lets the mocked platform channel answer, then lets animations finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  List<PrinterDeviceTile> tilesOnScreen(WidgetTester tester) => tester
      .widgetList<PrinterDeviceTile>(find.byType(PrinterDeviceTile))
      .toList();

  Future<void> openAddSheet(WidgetTester tester) async {
    await tester.tap(find.text('Add Printer'));
    await tester.pumpAndSettle();
    expect(find.byType(DsPrintAddPrinterSheet), findsOneWidget);
  }

  Future<void> chooseAndSearch(
      WidgetTester tester, PrinterInterfaceType type) async {
    await tester.tap(find.byKey(Key('ds_print_interface_${type.name}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ds_print_add_printer_next')));
    await settle(tester);
  }

  group('opening the screen', () {
    nativeTest('never scans — only the saved printers are listed',
        (tester) async {
      await savePrinters([_lan, _bluetooth], active: _bluetooth);

      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      expect(scans, isEmpty, reason: 'the screen must not auto-discover');
      expect(tilesOnScreen(tester).map((t) => t.device), [_lan, _bluetooth]);
    });

    nativeTest('with nothing saved: the Add button and a hint, no scan',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      expect(scans, isEmpty);
      expect(find.byType(DsPrintAddPrinterButton), findsOneWidget);
      expect(find.text('No printers added yet'), findsOneWidget);
      expect(find.byType(PrinterDeviceTile), findsNothing);
    });

    nativeTest(
        'each tile shows its connection type and icon, and the active '
        'printer is the selected one', (tester) async {
      await savePrinters([_usb, _lan, _bluetooth], active: _lan);

      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      expect(find.text('USB'), findsOneWidget);
      expect(find.text('Network (LAN)'), findsOneWidget);
      expect(find.text('Bluetooth'), findsOneWidget);
      expect(find.byIcon(Icons.usb), findsOneWidget);
      expect(find.byIcon(Icons.lan), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth), findsOneWidget);
      expect(find.text('192.168.1.50'), findsOneWidget);
      final selected =
          tilesOnScreen(tester).where((t) => t.isSelected).map((t) => t.device);
      expect(selected, [_lan]);
    });
  });

  group('adding a Bluetooth printer', () {
    nativeTest(
        'Add → Bluetooth → Next scans Bluetooth only; tapping the '
        'result saves it and makes it the active printer', (tester) async {
      nativeReplies['Bluetooth'] = [_nativePrinter(_bluetooth), 'finished'];
      await savePrinters([_usb], active: _usb);
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      await openAddSheet(tester);
      await chooseAndSearch(tester, PrinterInterfaceType.bluetooth);

      expect(scans, ['Bluetooth']);
      expect(find.text('00:11:62:AA:BB:CC'), findsOneWidget);
      await tester.tap(find.text('00:11:62:AA:BB:CC'));
      await settle(tester);

      expect(find.byType(DsPrintAddPrinterSheet), findsNothing);
      expect(tilesOnScreen(tester).map((t) => t.device), [_usb, _bluetooth]);
      expect(tilesOnScreen(tester).singleWhere((t) => t.isSelected).device,
          _bluetooth);
      expect(await activePrinter(), _bluetooth);
      expect(await storedPrinters(), [_usb, _bluetooth]);
    });

    nativeTest(
        'a denied "Nearby devices" permission explains itself and '
        'offers Retry', (tester) async {
      nativeReplies['Bluetooth'] = [
        'permission-requested',
        'failed-permission-denied',
        'finished',
      ];
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      await openAddSheet(tester);
      await chooseAndSearch(tester, PrinterInterfaceType.bluetooth);

      expect(
          find.text(
              'Allow the "Nearby devices" permission to search for printers'),
          findsOneWidget);
      expect(
          find.byKey(const Key('ds_print_add_printer_retry')), findsOneWidget);
      expect(await activePrinter(), isNull);
    });

    nativeTest('Bluetooth switched off says so', (tester) async {
      nativeReplies['Bluetooth'] = [
        PlatformException(code: 'BluetoothUnavailable', message: 'off'),
        'finished',
      ];
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      await openAddSheet(tester);
      await chooseAndSearch(tester, PrinterInterfaceType.bluetooth);

      expect(find.text('Turn on Bluetooth first'), findsOneWidget);
    });

    nativeTest(
        'an empty Bluetooth scan tells the user to pair first, and '
        'Retry scans again', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      await openAddSheet(tester);
      await chooseAndSearch(tester, PrinterInterfaceType.bluetooth);

      expect(find.text('No devices connected'), findsOneWidget);
      expect(
          find.text(
              "Pair the printer in your device's Bluetooth settings first"),
          findsOneWidget);

      nativeReplies['Bluetooth'] = [_nativePrinter(_bluetooth), 'finished'];
      await tester.tap(find.byKey(const Key('ds_print_add_printer_retry')));
      await settle(tester);

      expect(scans, ['Bluetooth', 'Bluetooth']);
      expect(find.text('00:11:62:AA:BB:CC'), findsOneWidget);
    });
  });

  group('adding a LAN printer', () {
    nativeTest('a scanned LAN printer is saved as LAN', (tester) async {
      nativeReplies['Lan'] = [_nativePrinter(_lan), 'finished'];
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      await openAddSheet(tester);
      await chooseAndSearch(tester, PrinterInterfaceType.lan);
      await tester.tap(find.text('192.168.1.50'));
      await settle(tester);

      expect(scans, ['Lan']);
      expect(await activePrinter(), _lan);
      expect(tilesOnScreen(tester).single.device, _lan);
    });

    nativeTest(
        'a typed IP address is saved as a LAN printer when the scan '
        'finds nothing', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      await openAddSheet(tester);
      await chooseAndSearch(tester, PrinterInterfaceType.lan);
      final field = find.byKey(const Key('ds_print_manual_ip_field'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '192.168.1.77');
      await tester.tap(find.byKey(const Key('ds_print_manual_ip_add')));
      await settle(tester);

      const typed = PrinterDevice(
          id: '192.168.1.77', interfaceType: PrinterInterfaceType.lan);
      expect(find.byType(DsPrintAddPrinterSheet), findsNothing);
      expect(await activePrinter(), typed);
      expect(tilesOnScreen(tester).single.device, typed);
    });

    nativeTest('an invalid IP is refused with a message and nothing is saved',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      await openAddSheet(tester);
      await chooseAndSearch(tester, PrinterInterfaceType.lan);
      final field = find.byKey(const Key('ds_print_manual_ip_field'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '300.1.1.1');
      await tester.tap(find.byKey(const Key('ds_print_manual_ip_add')));
      await settle(tester);

      expect(find.text('Invalid IP address'), findsOneWidget);
      expect(find.byType(DsPrintAddPrinterSheet), findsOneWidget);
      expect(await storedPrinters(), isEmpty);
    });

    nativeTest('the manual IP field is only offered for LAN', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      await openAddSheet(tester);
      await chooseAndSearch(tester, PrinterInterfaceType.bluetooth);

      expect(find.byKey(const Key('ds_print_manual_ip_field')), findsNothing);
    });
  });

  group('the add sheet', () {
    nativeTest('Next stays disabled until a connection type is chosen',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);
      await openAddSheet(tester);

      final next = find.byKey(const Key('ds_print_add_printer_next'));
      await tester.tap(next);
      await settle(tester);

      expect(scans, isEmpty);
      expect(find.text('Choose connection method'), findsOneWidget);
    });

    nativeTest('closing it adds nothing', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);
      await openAddSheet(tester);

      await tester.tap(find.byKey(const Key('ds_print_add_printer_close')));
      await settle(tester);

      expect(find.byType(DsPrintAddPrinterSheet), findsNothing);
      expect(await storedPrinters(), isEmpty);
    });
  });

  group('the selected printer is used by every print call', () {
    nativeTest(
        'tapping a printer selects it; the choice survives a rebuild '
        'and a silent print goes to it', (tester) async {
      await savePrinters([_lan, _bluetooth], active: _lan);
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      await tester.tap(find.text('00:11:62:AA:BB:CC'));
      await settle(tester);
      expect(tilesOnScreen(tester).singleWhere((t) => t.isSelected).device,
          _bluetooth);

      // A fresh screen reads the selection back from storage.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);
      expect(tilesOnScreen(tester).singleWhere((t) => t.isSelected).device,
          _bluetooth);

      // And the silent path (DsPrint.printBase64 / printUrlSilently) uses it.
      final result = await dsPrintResolve<AutoPrintUseCase>()(
          const HtmlPayload('<p>receipt</p>'));
      expect(result.isRight(), isTrue);
      final job =
          verify(() => printJob(captureAny())).captured.single as PrintJob;
      expect(job.device, _bluetooth);
    });

    nativeTest('a silent print with nothing selected prints nothing',
        (tester) async {
      await savePrinters([_lan]); // saved, but none active

      final result = await DsPrint.printHtml('<p>receipt</p>');

      expect(
          result, const Left<DsPrintFailure, Unit>(NoPrinterSelectedFailure()));
      expect(scans, isEmpty, reason: 'silent printing never auto-discovers');
      verifyNever(() => printJob(any()));
    });

    nativeTest('opened with a payload, tapping a printer prints to it',
        (tester) async {
      await savePrinters([_lan, _bluetooth]);
      await tester.pumpWidget(const MaterialApp(
          home: PrinterPickerScreen(payload: HtmlPayload('<p>x</p>'))));
      await settle(tester);

      await tester.tap(find.text('192.168.1.50'));
      await settle(tester);

      final job =
          verify(() => printJob(captureAny())).captured.single as PrintJob;
      expect(job.device, _lan);
      expect(await activePrinter(), _lan);
    });

    nativeTest(
        'opened with a payload, a newly added printer is printed to '
        'and the screen pops', (tester) async {
      nativeReplies['Bluetooth'] = [_nativePrinter(_bluetooth), 'finished'];
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  const PrinterPickerScreen(payload: HtmlPayload('<p>x</p>')),
            )),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);

      await openAddSheet(tester);
      await chooseAndSearch(tester, PrinterInterfaceType.bluetooth);
      await tester.tap(find.text('00:11:62:AA:BB:CC'));
      await settle(tester);

      final job =
          verify(() => printJob(captureAny())).captured.single as PrintJob;
      expect(job.device, _bluetooth);
      expect(find.byType(PrinterPickerScreen), findsNothing);
    });

    nativeTest('a print failure shows DsPrintMessageDialog, never a SnackBar',
        (tester) async {
      when(() => printJob(any())).thenAnswer(
          (_) async => const Left(NativePrintFailure('native crash')));
      await savePrinters([_lan]);
      await tester.pumpWidget(const MaterialApp(
          home: PrinterPickerScreen(payload: HtmlPayload('<p>x</p>'))));
      await settle(tester);

      await tester.tap(find.byType(PrinterDeviceTile).first);
      await settle(tester);

      expect(find.byType(DsPrintMessageDialog), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('removing a printer', () {
    nativeTest(
        'swipe + confirm removes it, and removing the active printer '
        'clears the selection', (tester) async {
      await savePrinters([_lan, _bluetooth], active: _lan);
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      await tester.drag(find.text('192.168.1.50'), const Offset(-600, 0));
      await settle(tester);
      await tester.tap(find.byKey(const Key('ds_print_confirm_remove')));
      await settle(tester);

      expect(tilesOnScreen(tester).map((t) => t.device), [_bluetooth]);
      expect(await storedPrinters(), [_bluetooth]);
      expect(await activePrinter(), isNull);
    });

    nativeTest('cancelling the confirm keeps the printer', (tester) async {
      await savePrinters([_lan], active: _lan);
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);

      await tester.drag(find.text('192.168.1.50'), const Offset(-600, 0));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(tilesOnScreen(tester).single.device, _lan);
      expect(await activePrinter(), _lan);
    });
  });

  group('showBluetooth / showLan control which options the sheet offers', () {
    tearDown(() => DsPrintConfig.current = null);

    Finder option(PrinterInterfaceType type) =>
        find.byKey(Key('ds_print_interface_${type.name}'));

    Future<void> pumpButton(WidgetTester tester,
        {bool? showBluetooth, bool? showLan}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: DsPrintAddPrinterButton(
              showBluetooth: showBluetooth,
              showLan: showLan,
            ),
          ),
        ),
      ));
      await openAddSheet(tester);
    }

    nativeTest('by default all three are offered', (tester) async {
      await pumpButton(tester);

      expect(option(PrinterInterfaceType.lan), findsOneWidget);
      expect(option(PrinterInterfaceType.bluetooth), findsOneWidget);
      expect(option(PrinterInterfaceType.usb), findsOneWidget);
    });

    nativeTest('showBluetooth: false hides Bluetooth only', (tester) async {
      await pumpButton(tester, showBluetooth: false);

      expect(option(PrinterInterfaceType.bluetooth), findsNothing);
      expect(option(PrinterInterfaceType.lan), findsOneWidget);
      expect(option(PrinterInterfaceType.usb), findsOneWidget);
    });

    nativeTest('showLan: false hides LAN only', (tester) async {
      await pumpButton(tester, showLan: false);

      expect(option(PrinterInterfaceType.lan), findsNothing);
      expect(option(PrinterInterfaceType.bluetooth), findsOneWidget);
      expect(option(PrinterInterfaceType.usb), findsOneWidget);
    });

    nativeTest('DsPrint.configure sets it app-wide', (tester) async {
      DsPrint.configure(
          const DsPrintConfig(showBluetooth: false, showLan: false));
      await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
      await settle(tester);
      await openAddSheet(tester);

      expect(option(PrinterInterfaceType.bluetooth), findsNothing);
      expect(option(PrinterInterfaceType.lan), findsNothing);
    });

    nativeTest('a value on the widget overrides DsPrint.configure',
        (tester) async {
      DsPrint.configure(const DsPrintConfig(showBluetooth: false));
      await pumpButton(tester, showBluetooth: true);

      expect(option(PrinterInterfaceType.bluetooth), findsOneWidget);
    });

    nativeTest('PrinterPickerScreen passes its flags to its Add button',
        (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: PrinterPickerScreen(showLan: false)));
      await settle(tester);
      await openAddSheet(tester);

      expect(option(PrinterInterfaceType.lan), findsNothing);
      expect(option(PrinterInterfaceType.bluetooth), findsOneWidget);
    });

    nativeTest('with both hidden, USB is pre-selected — Next scans USB at once',
        (tester) async {
      nativeReplies['Usb'] = [_nativePrinter(_usb), 'finished'];
      await pumpButton(tester, showBluetooth: false, showLan: false);

      expect(option(PrinterInterfaceType.usb), findsOneWidget);
      await tester.tap(find.byKey(const Key('ds_print_add_printer_next')));
      await settle(tester);

      expect(scans, ['Usb']);
      expect(find.text('usb-serial-1'), findsOneWidget);
    });

    test('availableTypes keeps the legacy order and always includes USB', () {
      expect(DsPrintAddPrinterSheet.availableTypes(), [
        PrinterInterfaceType.lan,
        PrinterInterfaceType.bluetooth,
        PrinterInterfaceType.usb,
      ]);
      expect(
          DsPrintAddPrinterSheet.availableTypes(
              showBluetooth: false, showLan: false),
          [PrinterInterfaceType.usb]);
    });
  });

  group('DsPrintAddPrinterButton (public, used without the screen)', () {
    nativeTest('works in a bare host screen and reports the added printer',
        (tester) async {
      nativeReplies['Lan'] = [_nativePrinter(_lan), 'finished'];
      PrinterDevice? added;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: DsPrintAddPrinterButton(
              onPrinterAdded: (device) => added = device,
            ),
          ),
        ),
      ));

      await openAddSheet(tester);
      await chooseAndSearch(tester, PrinterInterfaceType.lan);
      await tester.tap(find.text('192.168.1.50'));
      await settle(tester);

      expect(added, _lan);
      expect(await activePrinter(), _lan);
    });

    nativeTest('takes a custom label and style', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DsPrintAddPrinterButton(
            label: 'Connect printer',
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ),
      ));

      expect(find.text('Connect printer'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.style?.backgroundColor?.resolve({}), Colors.orange);
    });

    nativeTest('closing the sheet reports nothing', (tester) async {
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DsPrintAddPrinterButton(onPrinterAdded: (_) => calls++),
        ),
      ));

      await openAddSheet(tester);
      await tester.tap(find.byKey(const Key('ds_print_add_printer_close')));
      await settle(tester);

      expect(calls, 0);
    });
  });

  testWidgets(
    'builds on a completely empty container — no manual registration '
    '(regression for "InvoicePreviewCubit is not registered inside GetIt", '
    'reproduced via PrinterPickerScreen since InvoicePreviewScreen builds a '
    'WebViewController and needs a WebViewPlatform implementation this '
    'package has no in-memory fake for)',
    (tester) async {
      await dsPrintSl.reset();
      // Off Android, so nothing anywhere could reach a native channel.
      // Cleared in `finally`, not `addTearDown`: the binding asserts every
      // foundation debug variable is back to null when the test *body*
      // returns, which happens before any tearDown callback runs.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(const MaterialApp(home: PrinterPickerScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      expect(tester.takeException(), isNull);
    },
  );
}
