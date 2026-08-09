import 'package:shared_preferences/shared_preferences.dart';

import '../../core/error/ds_print_exception.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/entities/printer_interface_type.dart';

abstract class SelectedPrinterDataSource {
  Future<PrinterDevice?> read();

  Future<void> save(PrinterDevice device);

  Future<void> clear();
}

class SelectedPrinterDataSourceImpl implements SelectedPrinterDataSource {
  // Load-bearing: the host app already stores paired printers under these
  // exact strings (`cache_keys.dart`), so users must not have to re-pair
  // after this refactor.
  static const _deviceIdKey = 'printer-deviceId';
  static const _interfaceTypeKey = 'printer-device-interface-type';

  const SelectedPrinterDataSourceImpl();

  // Fetched per call instead of injected: this keeps DI registration for
  // this datasource (and everything above it) fully synchronous, so
  // `dsPrintInjection()` never has to become async just to hand the host a
  // zero-config API. `SharedPreferences.getInstance()` is cheap — the
  // plugin caches the underlying instance after the first call.
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<PrinterDevice?> read() async {
    try {
      final prefs = await _prefs;
      final id = prefs.getString(_deviceIdKey);
      if (id == null || id.trim().isEmpty) return null;
      final interfaceType = PrinterInterfaceType.fromNative(
        prefs.getString(_interfaceTypeKey),
      );
      return PrinterDevice(id: id, interfaceType: interfaceType);
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  @override
  Future<void> save(PrinterDevice device) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(_deviceIdKey, device.id);
      await prefs.setString(
        _interfaceTypeKey,
        device.interfaceType.nativeName,
      );
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_deviceIdKey);
      await prefs.remove(_interfaceTypeKey);
    } catch (e) {
      throw StorageException(e.toString());
    }
  }
}
