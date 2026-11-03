// Exercises the real PrinterDiscoveryDataSourceImpl against a mocked native
// side of `com.printer.discover/event`. This is the Dart half of the
// Bluetooth / LAN discovery contract with DsPrintPlugin.kt — what gets sent
// to native, and how every native reply is handled — which is everything
// short of real hardware.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ds_print/src/core/error/ds_print_exception.dart';
import 'package:ds_print/src/data/datasources/printer_discovery_datasource.dart';
import 'package:ds_print/src/domain/entities/printer_device.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = EventChannel('com.printer.discover/event');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const dataSource = PrinterDiscoveryDataSourceImpl(eventChannel: channel);

  /// Every `listen` argument native received, in order.
  late List<Object?> listenArguments;
  late int cancelCount;

  /// Installs a fake native side. [onListen] plays the part of
  /// `DsPrintPlugin.discoveryStreamHandler.onListen`.
  void mockNative(
      void Function(Object? argument, MockStreamHandlerEventSink events)
          onListen) {
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (argument, events) {
          listenArguments.add(argument);
          onListen(argument, events);
        },
        onCancel: (_) => cancelCount++,
      ),
    );
  }

  Map<String, String> printer(String id, String interfaceType) =>
      {'name': 'TSP100', 'id': id, 'interfaceType': interfaceType};

  setUp(() {
    listenArguments = [];
    cancelCount = 0;
  });

  tearDown(() => messenger.setMockStreamHandler(channel, null));

  group('the argument sent to native', () {
    test('is the exact nativeName the Kotlin `when` matches on', () async {
      mockNative((_, events) => events.success('finished'));

      await dataSource.discoverOnce(interfaceType: PrinterInterfaceType.lan);
      await dataSource.discoverOnce(
          interfaceType: PrinterInterfaceType.bluetooth);
      await dataSource.discoverOnce(interfaceType: PrinterInterfaceType.usb);

      expect(listenArguments, ['Lan', 'Bluetooth', 'Usb']);
    });

    test('is null when no type is given (legacy USB + LAN scan)', () async {
      mockNative((_, events) => events.success('finished'));

      await dataSource.discoverOnce();

      expect(listenArguments, [null]);
    });

    test('watch sends it too', () async {
      mockNative((_, events) => events.success('finished'));

      await dataSource
          .watch(interfaceType: PrinterInterfaceType.bluetooth)
          .toList();

      expect(listenArguments, ['Bluetooth']);
    });
  });

  group('discoverOnce', () {
    test('returns LAN printers found by a LAN scan', () async {
      mockNative((_, events) {
        events.success(printer('00:11:62:00:00:01', 'Lan'));
        events.success(printer('192.168.1.60', 'Lan'));
        events.success('finished');
      });

      final devices = await dataSource.discoverOnce(
          interfaceType: PrinterInterfaceType.lan);

      expect(devices, const [
        PrinterDevice(
            id: '00:11:62:00:00:01', interfaceType: PrinterInterfaceType.lan),
        PrinterDevice(
            id: '192.168.1.60', interfaceType: PrinterInterfaceType.lan),
      ]);
    });

    test('returns Bluetooth printers found by a Bluetooth scan', () async {
      mockNative((_, events) {
        events.success(printer('00:12:F3:1A:2B:3C', 'Bluetooth'));
        events.success('finished');
      });

      final devices = await dataSource.discoverOnce(
          interfaceType: PrinterInterfaceType.bluetooth);

      expect(devices, const [
        PrinterDevice(
            id: '00:12:F3:1A:2B:3C',
            interfaceType: PrinterInterfaceType.bluetooth),
      ]);
    });

    test(
        'drops devices of another type — a Bluetooth search never offers a '
        'USB or LAN printer', () async {
      mockNative((_, events) {
        events.success(printer('usb-1', 'Usb'));
        events.success(printer('bt-1', 'Bluetooth'));
        events.success(printer('lan-1', 'Lan'));
        events.success('finished');
      });

      final devices = await dataSource.discoverOnce(
          interfaceType: PrinterInterfaceType.bluetooth);

      expect(devices.map((d) => d.id), ['bt-1']);
    });

    test('keeps every type when no type was requested', () async {
      mockNative((_, events) {
        events.success(printer('usb-1', 'Usb'));
        events.success(printer('lan-1', 'Lan'));
        events.success('finished');
      });

      final devices = await dataSource.discoverOnce();

      expect(devices.map((d) => d.interfaceType),
          [PrinterInterfaceType.usb, PrinterInterfaceType.lan]);
    });

    test('de-duplicates a printer reported twice, and drops empty ids',
        () async {
      mockNative((_, events) {
        events.success(printer('lan-1', 'Lan'));
        events.success(printer('lan-1', 'Lan'));
        events.success(printer('', 'Lan'));
        events.success('finished');
      });

      final devices = await dataSource.discoverOnce(
          interfaceType: PrinterInterfaceType.lan);

      expect(devices.map((d) => d.id), ['lan-1']);
    });

    test('an empty scan is an empty list, not an error', () async {
      mockNative((_, events) => events.success('finished'));

      final devices = await dataSource.discoverOnce(
          interfaceType: PrinterInterfaceType.bluetooth);

      expect(devices, isEmpty);
    });

    test('"failed-permission-denied" -> PermissionDeniedException', () async {
      mockNative((_, events) {
        events.success('permission-requested');
        events.success('failed-permission-denied');
        events.success('finished');
      });

      expect(
        dataSource.discoverOnce(interfaceType: PrinterInterfaceType.bluetooth),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('a permission granted mid-scan still returns what native finds',
        () async {
      mockNative((_, events) {
        events.success('permission-requested');
        events.success('permission-granted');
        events.success(printer('bt-1', 'Bluetooth'));
        events.success('finished');
      });

      final devices = await dataSource.discoverOnce(
          interfaceType: PrinterInterfaceType.bluetooth);

      expect(devices.map((d) => d.id), ['bt-1']);
    });

    final unavailableCases = {
      'BluetoothUnavailable': PrinterInterfaceType.bluetooth,
      'NetworkUnavailable': PrinterInterfaceType.lan,
      'UsbUnavailable': PrinterInterfaceType.usb,
    };
    for (final entry in unavailableCases.entries) {
      test(
          'native error code ${entry.key} -> '
          'InterfaceUnavailableException(${entry.value.name})', () async {
        mockNative((_, events) {
          events.error(code: entry.key, message: 'radio is off');
          events.success('finished');
        });

        await expectLater(
          dataSource.discoverOnce(interfaceType: entry.value),
          throwsA(isA<InterfaceUnavailableException>()
              .having((e) => e.interfaceType, 'interfaceType', entry.value)),
        );
      });
    }

    test('any other native error -> DiscoveryException with its message',
        () async {
      mockNative((_, events) {
        events.error(code: 'DISCOVERY_FAILED', message: 'SDK exploded');
        events.success('finished');
      });

      await expectLater(
        dataSource.discoverOnce(interfaceType: PrinterInterfaceType.lan),
        throwsA(isA<DiscoveryException>()
            .having((e) => e.details, 'details', 'SDK exploded')),
      );
    });

    test('off Android -> UnsupportedPlatformException, native never called',
        () async {
      mockNative((_, events) => events.success('finished'));
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await expectLater(
          dataSource.discoverOnce(interfaceType: PrinterInterfaceType.lan),
          throwsA(isA<UnsupportedPlatformException>()),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(listenArguments, isEmpty);
    });

    // Timing tests run under testWidgets: its fake clock also drives the
    // test binding's platform-message delivery, which a bare `fakeAsync`
    // does not.
    testWidgets(
        'times out with what it has when native never says "finished", and '
        'cancels the native scan', (tester) async {
      mockNative((_, events) => events.success(printer('lan-1', 'Lan')));
      List<PrinterDevice>? result;

      dataSource
          .discoverOnce(
              interfaceType: PrinterInterfaceType.lan,
              timeout: const Duration(seconds: 10))
          .then((devices) => result = devices);

      await tester.pump(const Duration(seconds: 9));
      expect(result, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(result?.map((d) => d.id), ['lan-1']);
      await tester.pump();
      expect(cancelCount, 1);
    });

    testWidgets('does not time out while the permission dialog is on screen',
        (tester) async {
      late MockStreamHandlerEventSink nativeSink;
      mockNative((_, events) {
        nativeSink = events;
        events.success('permission-requested');
      });
      List<PrinterDevice>? result;
      Object? error;

      dataSource
          .discoverOnce(
              interfaceType: PrinterInterfaceType.bluetooth,
              timeout: const Duration(seconds: 10))
          .then((devices) => result = devices, onError: (e) => error = e);

      // The user takes a minute to read the "Nearby devices" prompt.
      await tester.pump(const Duration(minutes: 1));
      expect(result, isNull);
      expect(error, isNull);

      nativeSink.success('permission-granted');
      nativeSink.success(printer('bt-1', 'Bluetooth'));
      nativeSink.success('finished');
      await tester.pump();

      expect(result?.map((d) => d.id), ['bt-1']);
    });

    testWidgets(
        'the timeout restarts once permission is granted, so a scan that then '
        'hangs still ends', (tester) async {
      late MockStreamHandlerEventSink nativeSink;
      mockNative((_, events) {
        nativeSink = events;
        events.success('permission-requested');
      });
      List<PrinterDevice>? result;

      dataSource
          .discoverOnce(
              interfaceType: PrinterInterfaceType.bluetooth,
              timeout: const Duration(seconds: 10))
          .then((devices) => result = devices);
      await tester.pump(const Duration(seconds: 30));

      nativeSink.success('permission-granted');
      await tester.pump(const Duration(seconds: 11));

      expect(result, isEmpty);
    });
  });

  group('watch', () {
    test('emits each device and closes on "finished"', () async {
      mockNative((_, events) {
        events.success(printer('lan-1', 'Lan'));
        events.success(printer('lan-2', 'Lan'));
        events.success('finished');
      });

      final devices = await dataSource
          .watch(interfaceType: PrinterInterfaceType.lan)
          .toList();

      expect(devices.map((d) => d.id), ['lan-1', 'lan-2']);
    });

    test('ignores permission progress events', () async {
      mockNative((_, events) {
        events.success('permission-requested');
        events.success('permission-granted');
        events.success(printer('bt-1', 'Bluetooth'));
        events.success('finished');
      });

      final devices = await dataSource
          .watch(interfaceType: PrinterInterfaceType.bluetooth)
          .toList();

      expect(devices.map((d) => d.id), ['bt-1']);
    });

    test('surfaces a denied permission as a stream error', () async {
      mockNative((_, events) => events.success('failed-permission-denied'));

      expect(
        dataSource
            .watch(interfaceType: PrinterInterfaceType.bluetooth)
            .toList(),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  test('event names match the Kotlin constants in DsPrintPlugin.kt', () {
    // A typo on either side is a silent runtime no-op, so pin them.
    expect(PrinterDiscoveryDataSourceImpl.finishedEvent, 'finished');
    expect(PrinterDiscoveryDataSourceImpl.permissionDeniedEvent,
        'failed-permission-denied');
    expect(PrinterDiscoveryDataSourceImpl.permissionRequestedEvent,
        'permission-requested');
    expect(PrinterDiscoveryDataSourceImpl.permissionGrantedEvent,
        'permission-granted');
  });

  // testWidgets fails any test that ends with a timer still pending, so
  // this pins that a normal finish cancels the timeout.
  testWidgets('does not leak a pending timer after a normal finish',
      (tester) async {
    mockNative((_, events) => events.success('finished'));
    var finished = false;

    dataSource
        .discoverOnce(interfaceType: PrinterInterfaceType.lan)
        .then((_) => finished = true);
    await tester.pump();

    expect(finished, isTrue);
  });
}
