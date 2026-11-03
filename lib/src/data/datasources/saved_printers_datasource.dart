import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/error/ds_print_exception.dart';
import '../../domain/entities/printer_device.dart';
import '../models/printer_device_model.dart';

/// Every printer the user has added, in the order they were added.
///
/// Which one of them is *active* is not stored here — that stays under the
/// host app's legacy keys in [SelectedPrinterDataSource], which every print
/// call already reads.
abstract class SavedPrintersDataSource {
  Future<List<PrinterDevice>> readAll();

  /// No-op if [device] is already saved.
  Future<void> add(PrinterDevice device);

  Future<void> remove(PrinterDevice device);
}

class SavedPrintersDataSourceImpl implements SavedPrintersDataSource {
  static const savedPrintersKey = 'ds_print-saved-printers';

  // Owned by SelectedPrinterDataSource; read here only for the one-time
  // migration in [readAll].
  static const _legacyDeviceIdKey = 'printer-deviceId';
  static const _legacyInterfaceTypeKey = 'printer-device-interface-type';

  const SavedPrintersDataSourceImpl();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// The first read after upgrading finds no list yet. A user who had paired a
  /// printer under the old single-printer storage gets that printer seeded
  /// into the list (and persisted), so they never have to add it again.
  @override
  Future<List<PrinterDevice>> readAll() async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(savedPrintersKey);
      if (raw != null) return _decode(raw);

      final legacyId = prefs.getString(_legacyDeviceIdKey);
      if (legacyId == null || legacyId.trim().isEmpty) return const [];
      final migrated = [
        PrinterDeviceModel.fromChannel({
          'id': legacyId,
          'interfaceType': prefs.getString(_legacyInterfaceTypeKey),
        }),
      ];
      await _write(prefs, migrated);
      return migrated;
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  @override
  Future<void> add(PrinterDevice device) async {
    final printers = await readAll();
    if (printers.contains(device)) return;
    try {
      await _write(await _prefs, [...printers, device]);
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  @override
  Future<void> remove(PrinterDevice device) async {
    final printers = await readAll();
    try {
      await _write(await _prefs, printers.where((p) => p != device).toList());
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  Future<void> _write(SharedPreferences prefs, List<PrinterDevice> printers) {
    final encoded = jsonEncode([
      for (final printer in printers)
        {'id': printer.id, 'interfaceType': printer.interfaceType.nativeName},
    ]);
    return prefs.setString(savedPrintersKey, encoded);
  }

  /// Entries are the same `{id, interfaceType}` shape the discovery channel
  /// sends, so [PrinterDeviceModel.fromChannel] parses both. Anything
  /// unreadable is dropped rather than failing the whole list — one corrupt
  /// entry must not lock the user out of every printer they saved.
  List<PrinterDevice> _decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map) PrinterDeviceModel.fromChannel(entry),
    ].where((printer) => printer.isValid).toList();
  }
}
