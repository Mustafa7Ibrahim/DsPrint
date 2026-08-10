import 'package:ds_print/src/data/models/printer_device_model.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrinterDeviceModel.fromChannel', () {
    test('parses a well-formed map', () {
      final device = PrinterDeviceModel.fromChannel(const {
        'id': 'ABC-123',
        'interfaceType': 'Lan',
      });

      expect(device.id, 'ABC-123');
      expect(device.interfaceType, PrinterInterfaceType.lan);
    });

    test('interfaceType parsing is case-insensitive', () {
      for (final value in ['usb', 'USB', 'Usb']) {
        final device = PrinterDeviceModel.fromChannel({
          'id': 'x',
          'interfaceType': value,
        });
        expect(
          device.interfaceType,
          PrinterInterfaceType.usb,
          reason: 'failed to parse interfaceType "$value"',
        );
      }
    });

    test('unknown, null, or missing interfaceType falls back to usb', () {
      expect(
        PrinterDeviceModel.fromChannel(const {
          'id': 'x',
          'interfaceType': 'not-a-real-type',
        }).interfaceType,
        PrinterInterfaceType.usb,
      );
      expect(
        PrinterDeviceModel.fromChannel(const {
          'id': 'x',
          'interfaceType': null,
        }).interfaceType,
        PrinterInterfaceType.usb,
      );
      expect(
        PrinterDeviceModel.fromChannel(const {'id': 'x'}).interfaceType,
        PrinterInterfaceType.usb,
      );
    });

    test('non-String values are coerced via toString()', () {
      final device = PrinterDeviceModel.fromChannel(const {
        'id': 12345,
        'interfaceType': 'Bluetooth',
      });

      expect(device.id, '12345');
      expect(device.interfaceType, PrinterInterfaceType.bluetooth);
    });

    test('missing id yields an empty id and isValid is false, not a throw', () {
      final device =
          PrinterDeviceModel.fromChannel(const {'interfaceType': 'Usb'});

      expect(device.id, '');
      expect(device.isValid, isFalse);
    });
  });
}
