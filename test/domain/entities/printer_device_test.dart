import 'package:flutter_test/flutter_test.dart';

import 'package:ds_print/src/data/models/printer_device_model.dart';
import 'package:ds_print/src/domain/entities/printer_device.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';

void main() {
  test(
      'a discovery model equals the stored entity for the same printer '
      '(Equatable alone would say no — different runtimeType)', () {
    const entity = PrinterDevice(
        id: '192.168.1.50', interfaceType: PrinterInterfaceType.lan);
    const model = PrinterDeviceModel(
        id: '192.168.1.50', interfaceType: PrinterInterfaceType.lan);

    expect(model, entity);
    expect(entity, model);
    expect(model.hashCode, entity.hashCode);
    expect({entity, model}, hasLength(1));
  });

  test('a different id or interface is a different printer', () {
    const device =
        PrinterDevice(id: 'a', interfaceType: PrinterInterfaceType.bluetooth);

    expect(
        device,
        isNot(const PrinterDevice(
            id: 'b', interfaceType: PrinterInterfaceType.bluetooth)));
    expect(
        device,
        isNot(const PrinterDevice(
            id: 'a', interfaceType: PrinterInterfaceType.lan)));
  });
}
