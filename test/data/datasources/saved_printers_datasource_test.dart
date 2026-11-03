// Runs the real SharedPreferences-backed storage (in-memory mock) for the
// saved-printer list and the active printer, the two halves every print call
// and the printers screen rely on.
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ds_print/src/core/error/ds_print_failure.dart';
import 'package:ds_print/src/data/datasources/saved_printers_datasource.dart';
import 'package:ds_print/src/data/datasources/selected_printer_datasource.dart';
import 'package:ds_print/src/data/models/printer_device_model.dart';
import 'package:ds_print/src/data/repositories/saved_printers_repository_impl.dart';
import 'package:ds_print/src/domain/entities/printer_device.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';

void main() {
  const dataSource = SavedPrintersDataSourceImpl();
  const selected = SelectedPrinterDataSourceImpl();

  const lan = PrinterDevice(
      id: '192.168.1.50', interfaceType: PrinterInterfaceType.lan);
  const bluetooth = PrinterDevice(
      id: '00:11:62:AA:BB:CC', interfaceType: PrinterInterfaceType.bluetooth);
  const usb = PrinterDevice(
      id: 'usb-serial-1', interfaceType: PrinterInterfaceType.usb);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SavedPrintersDataSourceImpl', () {
    test('starts empty', () async {
      expect(await dataSource.readAll(), isEmpty);
    });

    test('LAN, Bluetooth and USB printers round-trip with their type',
        () async {
      await dataSource.add(lan);
      await dataSource.add(bluetooth);
      await dataSource.add(usb);

      expect(await dataSource.readAll(), [lan, bluetooth, usb]);
    });

    test('stores the exact native type names the Kotlin side matches on',
        () async {
      await dataSource.add(lan);
      await dataSource.add(bluetooth);

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(
          prefs.getString(SavedPrintersDataSourceImpl.savedPrintersKey)!);
      expect(stored, [
        {'id': '192.168.1.50', 'interfaceType': 'Lan'},
        {'id': '00:11:62:AA:BB:CC', 'interfaceType': 'Bluetooth'},
      ]);
    });

    test(
        'adding the same printer twice keeps one copy — including when one '
        'copy is a discovery model and the other a plain entity', () async {
      await dataSource.add(lan);
      await dataSource.add(const PrinterDeviceModel(
          id: '192.168.1.50', interfaceType: PrinterInterfaceType.lan));

      expect(await dataSource.readAll(), [lan]);
    });

    test('the same id on different interfaces is two printers', () async {
      await dataSource.add(lan);
      await dataSource.add(const PrinterDevice(
          id: '192.168.1.50', interfaceType: PrinterInterfaceType.usb));

      expect(await dataSource.readAll(), hasLength(2));
    });

    test('remove drops only that printer', () async {
      await dataSource.add(lan);
      await dataSource.add(bluetooth);

      await dataSource.remove(lan);

      expect(await dataSource.readAll(), [bluetooth]);
    });

    test('migrates a printer paired under the legacy single-printer keys',
        () async {
      SharedPreferences.setMockInitialValues({
        'printer-deviceId': '00:11:62:AA:BB:CC',
        'printer-device-interface-type': 'Bluetooth',
      });

      expect(await dataSource.readAll(), [bluetooth]);
      // Persisted, so removing it later sticks.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SavedPrintersDataSourceImpl.savedPrintersKey),
          isNotNull);
    });

    test('does not re-migrate once the list exists, even if emptied', () async {
      SharedPreferences.setMockInitialValues({
        'printer-deviceId': 'usb-serial-1',
        'printer-device-interface-type': 'Usb',
      });
      await dataSource.remove(usb);

      expect(await dataSource.readAll(), isEmpty);
    });

    test('a corrupt list reads as empty instead of failing forever', () async {
      SharedPreferences.setMockInitialValues(
          {SavedPrintersDataSourceImpl.savedPrintersKey: 'not json'});

      expect(await dataSource.readAll(), isEmpty);
    });

    test('unreadable entries are skipped, readable ones kept', () async {
      SharedPreferences.setMockInitialValues({
        SavedPrintersDataSourceImpl.savedPrintersKey: jsonEncode([
          {'id': '', 'interfaceType': 'Lan'},
          'garbage',
          {'id': '192.168.1.50', 'interfaceType': 'Lan'},
        ]),
      });

      expect(await dataSource.readAll(), [lan]);
    });
  });

  group('SelectedPrinterDataSourceImpl (the active printer)', () {
    test(
        'LAN and Bluetooth printers are saved under the legacy keys with the '
        'exact native type names', () async {
      for (final (device, nativeName) in [
        (lan, 'Lan'),
        (bluetooth, 'Bluetooth'),
      ]) {
        await selected.save(device);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('printer-deviceId'), device.id);
        expect(prefs.getString('printer-device-interface-type'), nativeName);
        expect(await selected.read(), device);
      }
    });
  });

  group('SavedPrintersRepositoryImpl', () {
    test('success paths return Right', () async {
      const repo = SavedPrintersRepositoryImpl(dataSource);

      expect(await repo.add(lan), const Right<DsPrintFailure, Unit>(unit));
      final all = await repo.readAll();
      expect(all.getOrElse(() => []), [lan]);
      expect(await repo.remove(lan), const Right<DsPrintFailure, Unit>(unit));
    });

    test('a storage error becomes Left(StorageFailure), never a throw',
        () async {
      final repo = SavedPrintersRepositoryImpl(_ThrowingDataSource());

      expect((await repo.readAll()).isLeft(), isTrue);
      expect(await repo.add(lan),
          const Left<DsPrintFailure, Unit>(StorageFailure('Exception: disk')));
      expect((await repo.remove(lan)).isLeft(), isTrue);
    });
  });
}

class _ThrowingDataSource implements SavedPrintersDataSource {
  @override
  Future<void> add(PrinterDevice device) async => throw Exception('disk');

  @override
  Future<List<PrinterDevice>> readAll() async => throw Exception('disk');

  @override
  Future<void> remove(PrinterDevice device) async => throw Exception('disk');
}
