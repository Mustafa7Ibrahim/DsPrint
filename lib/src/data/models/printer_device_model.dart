import '../../domain/entities/printer_device.dart';
import '../../domain/entities/printer_interface_type.dart';

class PrinterDeviceModel extends PrinterDevice {
  const PrinterDeviceModel({required super.id, required super.interfaceType});

  /// `id`/`interfaceType` may arrive as non-`String` types over the platform
  /// channel — `?.toString()` normalizes them. A missing/null id yields an
  /// empty-string id (so `isValid` is false) rather than throwing.
  factory PrinterDeviceModel.fromChannel(Map<dynamic, dynamic> map) {
    return PrinterDeviceModel(
      id: map['id']?.toString() ?? '',
      interfaceType:
          PrinterInterfaceType.fromNative(map['interfaceType']?.toString()),
    );
  }
}
