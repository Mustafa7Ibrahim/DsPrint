import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ds_print/src/core/error/ds_print_exception.dart';
import 'package:ds_print/src/core/value/paper_width.dart';
import 'package:ds_print/src/data/datasources/printer_native_datasource.dart';
import 'package:ds_print/src/domain/entities/print_job.dart';
import 'package:ds_print/src/domain/entities/print_payload.dart';
import 'package:ds_print/src/domain/entities/printer_device.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';

import '../../helpers/test_payloads.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.printer.html/sendToNative');
  const eventChannel = EventChannel('com.printer.html/listenFromNative');
  const codec = StandardMethodCodec();
  // setMockMethodCallHandler only accepts a MethodChannel - this is how the
  // EventChannel's own 'listen'/'cancel' handshake is intercepted, since an
  // EventChannel talks over a channel with the same name/codec underneath.
  const eventChannelAsMethodChannel = MethodChannel(
    'com.printer.html/listenFromNative',
    codec,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Pushes [event] on the result event channel, as the native side would
  /// after handling a `fromFlutter` call.
  void pushResultEvent(dynamic event) {
    messenger.handlePlatformMessage(
      eventChannel.name,
      codec.encodeSuccessEnvelope(event),
      (_) {},
    );
  }

  setUp(() {
    // Event channel handshake ('listen'/'cancel') needs a registered mock
    // handler or `receiveBroadcastStream()` never actually subscribes.
    messenger.setMockMethodCallHandler(
        eventChannelAsMethodChannel, (call) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockMethodCallHandler(eventChannelAsMethodChannel, null);
  });

  PrintJob buildJob({required PrintPayload payload, int copies = 1}) {
    return PrintJob(
      payload: payload,
      device: const PrinterDevice(
          id: 'device-1', interfaceType: PrinterInterfaceType.usb),
      paperWidth: PaperWidth.html,
      copies: copies,
    );
  }

  test('method channel name and method are exactly the native contract', () {
    expect(methodChannel.name, 'com.printer.html/sendToNative');
  });

  test(
      'a large (~2.5 MB) payload is delivered as ordered fromFlutter calls that reassemble losslessly',
      () async {
    final calls = <Map<Object?, Object?>>[];
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      expect(call.method, 'fromFlutter');
      final args = call.arguments as Map;
      calls.add(args);
      if (args['status'] == 'completed' || args['status'] == 'one-index') {
        pushResultEvent('success');
      }
      return null;
    });

    final dataSource = PrinterNativeDataSourceImpl(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );
    final payload = twoPointFiveMbPayload;

    await dataSource.print(buildJob(payload: HtmlPayload(payload)));

    expect(calls.length, 2500); // 2.5M chars / 1000-char chunks

    for (var i = 0; i < calls.length; i++) {
      expect(calls[i]['index'], i);
    }
    expect(calls.first['status'], 'start');
    expect(calls.last['status'], 'completed');
    for (var i = 1; i < calls.length - 1; i++) {
      expect(calls[i]['status'], 'progress');
    }

    final reassembled = calls.map((c) => c['data'] as String).join();
    expect(reassembled, payload);
  });

  test("native 'failed' event throws NativePrintException", () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      final args = call.arguments as Map;
      if (args['status'] == 'one-index') {
        pushResultEvent('failed');
      }
      return null;
    });

    final dataSource = PrinterNativeDataSourceImpl(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );

    await expectLater(
      dataSource.print(buildJob(payload: const HtmlPayload('short payload'))),
      throwsA(isA<NativePrintException>()),
    );
  });

  test(
      'no native reply within resultTimeout throws NativePrintException("timeout")',
      () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      // Deliberately never pushes a result event.
      return null;
    });

    final dataSource = PrinterNativeDataSourceImpl(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
      resultTimeout: const Duration(milliseconds: 30),
    );

    try {
      await dataSource
          .print(buildJob(payload: const HtmlPayload('short payload')));
      fail('expected a NativePrintException');
    } on NativePrintException catch (e) {
      expect(e.details, 'timeout');
    }
  });

  test('an empty payload throws EmptyPayloadException before any channel call',
      () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      return null;
    });

    final dataSource = PrinterNativeDataSourceImpl(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );

    await expectLater(
      dataSource.print(buildJob(payload: const HtmlPayload('   '))),
      throwsA(isA<EmptyPayloadException>()),
    );
    expect(calls, isEmpty);
  });

  test('copies: 2 sends the full chunk sequence twice, sequentially', () async {
    final calls = <Map<Object?, Object?>>[];
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      final args = call.arguments as Map;
      calls.add(args);
      if (args['status'] == 'completed' || args['status'] == 'one-index') {
        pushResultEvent('success');
      }
      return null;
    });

    final dataSource = PrinterNativeDataSourceImpl(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );
    // 2500 chars -> 3 chunks of [1000, 1000, 500] per copy.
    final payload = bigPayload(2500);

    await dataSource.print(buildJob(payload: HtmlPayload(payload), copies: 2));

    expect(calls.length, 6); // 3 chunks x 2 copies

    final firstCopy = calls.sublist(0, 3);
    final secondCopy = calls.sublist(3, 6);
    for (final copy in [firstCopy, secondCopy]) {
      expect(copy.map((c) => c['index']), [0, 1, 2]);
      expect(copy.first['status'], 'start');
      expect(copy[1]['status'], 'progress');
      expect(copy.last['status'], 'completed');
    }
    // Sequential, not interleaved: the whole first copy's data precedes the
    // whole second copy's data in call order.
    expect(firstCopy.map((c) => c['data']).join(), payload);
    expect(secondCopy.map((c) => c['data']).join(), payload);
  });
}
