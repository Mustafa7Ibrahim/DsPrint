import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/value/ipv4_address.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/entities/printer_interface_type.dart';
import '../../domain/usecases/add_printer_usecase.dart';
import '../../domain/usecases/discover_printers_usecase.dart';
import 'add_printer_state.dart';

/// Drives the Add Printer sheet: choose a connection type, scan only that
/// type, then save the printer the user taps (or, for LAN, types in).
class AddPrinterCubit extends Cubit<AddPrinterState> {
  final DiscoverPrintersUseCase _discoverPrinters;
  final AddPrinterUseCase _addPrinter;

  PrinterInterfaceType? _interfaceType;

  AddPrinterCubit({
    required DiscoverPrintersUseCase discoverPrinters,
    required AddPrinterUseCase addPrinter,
  })  : _discoverPrinters = discoverPrinters,
        _addPrinter = addPrinter,
        super(const AddPrinterChoosingType());

  void chooseType(PrinterInterfaceType interfaceType) {
    _interfaceType = interfaceType;
    emit(AddPrinterChoosingType(interfaceType));
  }

  /// "Next", and "Retry" after an empty or failed scan.
  Future<void> search() async {
    final interfaceType = _interfaceType;
    if (interfaceType == null || state is AddPrinterSearching) return;
    emit(AddPrinterSearching(interfaceType));
    final result = await _discoverPrinters(interfaceType: interfaceType);
    // The sheet may have been dismissed mid-scan.
    if (isClosed) return;
    result.fold(
      (failure) => emit(AddPrinterFailure(interfaceType, failure)),
      (devices) => emit(AddPrinterResults(interfaceType, devices)),
    );
  }

  void back() => emit(AddPrinterChoosingType(_interfaceType));

  Future<void> addDevice(PrinterDevice device) async {
    if (state is AddPrinterSaving || state is AddPrinterAdded) return;
    emit(AddPrinterSaving(device.interfaceType));
    final result = await _addPrinter(device);
    if (isClosed) return;
    result.fold(
      (failure) => emit(AddPrinterFailure(device.interfaceType, failure)),
      (_) => emit(AddPrinterAdded(device)),
    );
  }

  /// Adds a LAN printer by the IP address the user typed. Returns `false`,
  /// and does nothing, when [ipAddress] isn't a valid IPv4 address.
  Future<bool> addManualLan(String ipAddress) async {
    final trimmed = ipAddress.trim();
    if (!isValidIpv4(trimmed)) return false;
    await addDevice(
      PrinterDevice(id: trimmed, interfaceType: PrinterInterfaceType.lan),
    );
    return true;
  }
}
