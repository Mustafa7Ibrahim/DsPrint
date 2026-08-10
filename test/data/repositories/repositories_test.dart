import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ds_print/src/core/error/ds_print_exception.dart';
import 'package:ds_print/src/core/error/ds_print_failure.dart';
import 'package:ds_print/src/core/value/paper_width.dart';
import 'package:ds_print/src/data/datasources/printer_discovery_datasource.dart';
import 'package:ds_print/src/data/datasources/printer_native_datasource.dart';
import 'package:ds_print/src/data/datasources/selected_printer_datasource.dart';
import 'package:ds_print/src/data/models/printer_device_model.dart';
import 'package:ds_print/src/data/repositories/invoice_capture_repository_impl.dart';
import 'package:ds_print/src/data/repositories/printer_discovery_repository_impl.dart';
import 'package:ds_print/src/data/repositories/printer_repository_impl.dart';
import 'package:ds_print/src/data/repositories/selected_printer_repository_impl.dart';
import 'package:ds_print/src/data/services/print_job_queue.dart';
import 'package:ds_print/src/domain/entities/print_job.dart';
import 'package:ds_print/src/domain/entities/print_payload.dart';
import 'package:ds_print/src/domain/entities/printer_device.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';
import 'package:ds_print/src/domain/ports/invoice_render_port.dart';

class FakeInvoiceRenderPort implements InvoiceRenderPort {
  FakeInvoiceRenderPort({this.result, this.errorToThrow});

  final String? result;
  final Object? errorToThrow;

  @override
  Future<String> renderUrlToBase64Png(String url) async {
    if (errorToThrow != null) throw errorToThrow!;
    return result!;
  }
}

class FakePrinterDiscoveryDataSource implements PrinterDiscoveryDataSource {
  FakePrinterDiscoveryDataSource({
    this.devices = const [],
    this.discoverOnceError,
    this.watchError,
  });

  final List<PrinterDeviceModel> devices;
  final Object? discoverOnceError;
  final Object? watchError;

  @override
  Stream<PrinterDeviceModel> watch(PrinterInterfaceType interfaceType) {
    if (watchError != null) return Stream.error(watchError!);
    return Stream.fromIterable(devices);
  }

  @override
  Future<List<PrinterDeviceModel>> discoverOnce(
    PrinterInterfaceType interfaceType, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (discoverOnceError != null) throw discoverOnceError!;
    return devices;
  }
}

class FakePrinterNativeDataSource implements PrinterNativeDataSource {
  FakePrinterNativeDataSource({this.errorToThrow});

  final Object? errorToThrow;

  @override
  Future<void> print(PrintJob job) async {
    if (errorToThrow != null) throw errorToThrow!;
  }
}

class FakeSelectedPrinterDataSource implements SelectedPrinterDataSource {
  FakeSelectedPrinterDataSource({this.deviceToReturn, this.errorToThrow});

  final PrinterDevice? deviceToReturn;
  final Object? errorToThrow;

  final List<PrinterDevice> saved = [];
  int clearCalls = 0;

  @override
  Future<PrinterDevice?> read() async {
    if (errorToThrow != null) throw errorToThrow!;
    return deviceToReturn;
  }

  @override
  Future<void> save(PrinterDevice device) async {
    if (errorToThrow != null) throw errorToThrow!;
    saved.add(device);
  }

  @override
  Future<void> clear() async {
    if (errorToThrow != null) throw errorToThrow!;
    clearCalls++;
  }
}

void main() {
  const device =
      PrinterDevice(id: 'device-1', interfaceType: PrinterInterfaceType.usb);
  const job = PrintJob(
    payload: HtmlPayload('<html></html>'),
    device: device,
    paperWidth: PaperWidth.html,
  );

  group('InvoiceCaptureRepositoryImpl', () {
    test('success -> Right(ImageBase64Payload)', () async {
      final repo = InvoiceCaptureRepositoryImpl(
          FakeInvoiceRenderPort(result: 'base64=='));

      final result = await repo.captureUrl('https://example.com');

      expect(
          result,
          const Right<DsPrintFailure, ImageBase64Payload>(
              ImageBase64Payload('base64==')));
    });

    test('CaptureException -> Left(CaptureFailure) with matching details',
        () async {
      final repo = InvoiceCaptureRepositoryImpl(
        FakeInvoiceRenderPort(
            errorToThrow: const CaptureException('boundary was null')),
      );

      final result = await repo.captureUrl('https://example.com');

      expect(
          result,
          const Left<DsPrintFailure, ImageBase64Payload>(
              CaptureFailure('boundary was null')));
    });

    test(
        'a different DsPrintException still maps to CaptureFailure (via its message)',
        () async {
      final repo = InvoiceCaptureRepositoryImpl(
        FakeInvoiceRenderPort(
            errorToThrow: const UnsupportedPlatformException()),
      );

      final result = await repo.captureUrl('https://example.com');

      expect(result.isLeft(), isTrue);
      result.fold((failure) => expect(failure, isA<CaptureFailure>()),
          (_) => fail('expected Left'));
    });

    test('an arbitrary Exception is caught and mapped, never rethrown',
        () async {
      final repo = InvoiceCaptureRepositoryImpl(
        FakeInvoiceRenderPort(errorToThrow: Exception('unexpected')),
      );

      // If the exception were rethrown instead of mapped, this `await` would
      // throw and fail the test instead of yielding a Left.
      final result = await repo.captureUrl('https://example.com');

      expect(result.isLeft(), isTrue);
    });
  });

  group('PrinterDiscoveryRepositoryImpl.discoverOnce', () {
    test('success -> Right(devices)', () async {
      final models = [
        const PrinterDeviceModel(
            id: 'a', interfaceType: PrinterInterfaceType.usb),
        const PrinterDeviceModel(
            id: 'b', interfaceType: PrinterInterfaceType.lan),
      ];
      final repo = PrinterDiscoveryRepositoryImpl(
        FakePrinterDiscoveryDataSource(devices: models),
      );

      final result = await repo.discoverOnce();

      expect(result, Right<DsPrintFailure, List<PrinterDevice>>(models));
    });

    test('every DsPrintException subtype maps to its matching DsPrintFailure',
        () async {
      final cases = <DsPrintException, DsPrintFailure>{
        const EmptyPayloadException(): const EmptyPayloadFailure(),
        const NoDeviceFoundException(): const NoDeviceFoundFailure(),
        const UnsupportedPlatformException():
            const UnsupportedPlatformFailure(),
        const CaptureException('d'): const CaptureFailure('d'),
        const NativePrintException('d'): const NativePrintFailure('d'),
        const StorageException('d'): const StorageFailure('d'),
      };

      for (final entry in cases.entries) {
        final repo = PrinterDiscoveryRepositoryImpl(
          FakePrinterDiscoveryDataSource(discoverOnceError: entry.key),
        );
        final result = await repo.discoverOnce();
        expect(result, Left<DsPrintFailure, List<PrinterDevice>>(entry.value));
      }
    });

    test('an arbitrary Exception is caught and mapped, never rethrown',
        () async {
      final repo = PrinterDiscoveryRepositoryImpl(
        FakePrinterDiscoveryDataSource(discoverOnceError: Exception('boom')),
      );

      final result = await repo.discoverOnce();

      expect(result.isLeft(), isTrue);
    });
  });

  group('PrinterDiscoveryRepositoryImpl.watchDiscoveredDevices', () {
    test('success -> a Right per discovered device', () async {
      final models = [
        const PrinterDeviceModel(
            id: 'a', interfaceType: PrinterInterfaceType.usb)
      ];
      final repo = PrinterDiscoveryRepositoryImpl(
          FakePrinterDiscoveryDataSource(devices: models));

      final results = await repo.watchDiscoveredDevices().toList();

      expect(results, [Right<DsPrintFailure, PrinterDevice>(models.first)]);
    });

    test('a DsPrintException on the stream maps to its matching failure',
        () async {
      final repo = PrinterDiscoveryRepositoryImpl(
        FakePrinterDiscoveryDataSource(
            watchError: const UnsupportedPlatformException()),
      );

      final results = await repo.watchDiscoveredDevices().toList();

      expect(results, [
        const Left<DsPrintFailure, PrinterDevice>(UnsupportedPlatformFailure())
      ]);
    });
  });

  group('PrinterRepositoryImpl.print', () {
    test('success -> Right(unit)', () async {
      final repo = PrinterRepositoryImpl(
        dataSource: FakePrinterNativeDataSource(),
        queue: PrintJobQueue(),
      );

      final result = await repo.print(job);

      expect(result, const Right<DsPrintFailure, Unit>(unit));
    });

    test('EmptyPayloadException -> Left(EmptyPayloadFailure)', () async {
      final repo = PrinterRepositoryImpl(
        dataSource: FakePrinterNativeDataSource(
            errorToThrow: const EmptyPayloadException()),
        queue: PrintJobQueue(),
      );

      final result = await repo.print(job);

      expect(result, const Left<DsPrintFailure, Unit>(EmptyPayloadFailure()));
    });

    test(
        'NativePrintException -> Left(NativePrintFailure) with matching details',
        () async {
      final repo = PrinterRepositoryImpl(
        dataSource: FakePrinterNativeDataSource(
            errorToThrow: const NativePrintException('native crash')),
        queue: PrintJobQueue(),
      );

      final result = await repo.print(job);

      expect(result,
          const Left<DsPrintFailure, Unit>(NativePrintFailure('native crash')));
    });

    test(
        'a different DsPrintException still maps to NativePrintFailure (via its message)',
        () async {
      final repo = PrinterRepositoryImpl(
        dataSource: FakePrinterNativeDataSource(
            errorToThrow: const StorageException('disk full')),
        queue: PrintJobQueue(),
      );

      final result = await repo.print(job);

      expect(result.isLeft(), isTrue);
      result.fold((failure) => expect(failure, isA<NativePrintFailure>()),
          (_) => fail('expected Left'));
    });

    test('an arbitrary Exception is caught and mapped, never rethrown',
        () async {
      final repo = PrinterRepositoryImpl(
        dataSource:
            FakePrinterNativeDataSource(errorToThrow: Exception('boom')),
        queue: PrintJobQueue(),
      );

      final result = await repo.print(job);

      expect(result.isLeft(), isTrue);
    });
  });

  group('SelectedPrinterRepositoryImpl', () {
    test('read: success -> Right(device)', () async {
      final repo = SelectedPrinterRepositoryImpl(
          FakeSelectedPrinterDataSource(deviceToReturn: device));

      final result = await repo.read();

      expect(result, const Right<DsPrintFailure, PrinterDevice?>(device));
    });

    test('read: StorageException -> Left(StorageFailure)', () async {
      final repo = SelectedPrinterRepositoryImpl(
        FakeSelectedPrinterDataSource(
            errorToThrow: const StorageException('read failed')),
      );

      final result = await repo.read();

      expect(
          result,
          const Left<DsPrintFailure, PrinterDevice?>(
              StorageFailure('read failed')));
    });

    test('read: an arbitrary Exception is caught and mapped, never rethrown',
        () async {
      final repo = SelectedPrinterRepositoryImpl(
        FakeSelectedPrinterDataSource(errorToThrow: Exception('boom')),
      );

      final result = await repo.read();

      expect(result.isLeft(), isTrue);
    });

    test('save: success -> Right(unit)', () async {
      final fakeDataSource = FakeSelectedPrinterDataSource();
      final repo = SelectedPrinterRepositoryImpl(fakeDataSource);

      final result = await repo.save(device);

      expect(result, const Right<DsPrintFailure, Unit>(unit));
      expect(fakeDataSource.saved, [device]);
    });

    test('save: StorageException -> Left(StorageFailure)', () async {
      final repo = SelectedPrinterRepositoryImpl(
        FakeSelectedPrinterDataSource(
            errorToThrow: const StorageException('write failed')),
      );

      final result = await repo.save(device);

      expect(result,
          const Left<DsPrintFailure, Unit>(StorageFailure('write failed')));
    });

    test('clear: success -> Right(unit)', () async {
      final fakeDataSource = FakeSelectedPrinterDataSource();
      final repo = SelectedPrinterRepositoryImpl(fakeDataSource);

      final result = await repo.clear();

      expect(result, const Right<DsPrintFailure, Unit>(unit));
      expect(fakeDataSource.clearCalls, 1);
    });

    test('clear: an arbitrary Exception is caught and mapped, never rethrown',
        () async {
      final repo = SelectedPrinterRepositoryImpl(
        FakeSelectedPrinterDataSource(errorToThrow: Exception('boom')),
      );

      final result = await repo.clear();

      expect(result.isLeft(), isTrue);
    });
  });
}
